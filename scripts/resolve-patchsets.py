#!/usr/bin/env python

import argparse
import collections
import copy
import json
import logging
import os
import re
import requests
import sys
import traceback


DEPENDS_RE = re.compile('depends-on:[ ]*[a-zA-Z0-9]+', re.IGNORECASE)


def dbg(msg):
    logging.debug(msg)


def err(msg):
    logging.error(msg)


class DependencyLoopError(Exception):
    pass


class GerritRequestError(Exception):
    pass


class Session(object):
    def __init__(self, url):
        self._url = url

    def _make_url(self, request):
        return self._url + request

    def get(self, request, params=None):
        url = self._make_url(request)
        res = requests.get(url, params=params)
        if not res.ok:
            raise GerritRequestError("Failed request %s with code %s" % (res.url, res.status_code))
        response = res.text.strip(')]}\'')
        return json.loads(response)


class Change(object):
    def __init__(self, data, gerrit):
        self._data = data
        self._files = None
        self._gerrit = gerrit
        dbg("Change: %s" % self._data)

    def __hash__(self):
        return hash(self.change_id)

    def __eq__(self, value):
        return self.change_id == value.change_id

    def __gt__(self, value):
        return self.change_id > value.change_id

    def __lt__(self, value):
        return self.change_id < value.change_id

    @property
    def id(self):
        return self._data['id']

    @property
    def status(self):
        return self._data['status']

    @property
    def project(self):
        return self._data['project']

    @property
    def branch(self):
        return self._data['branch']

    @property
    def change_id(self):
        return self._data['change_id']

    @property
    def ref(self):
        return self._data['revisions'][self.revision]['ref']

    @property
    def number(self):
        return self._data.get('_number', self.ref.split("/")[3])

    @property
    def revision(self):
        return self._data['current_revision']

    @property
    def revision_number(self):
        return self._data['revisions'][self.revision].get(
            '_number', self.ref.split("/")[4])

    @property
    def files(self):
        return self._files

    def set_files(self, files):
        self._files = files

    @property
    def depends_on(self):
        result = []
        # collect parents by SHA - non-merged review can have only one parent
        parents = self._data['revisions'][self.revision]['commit']['parents']
        if len(parents != 1):
            # let's fail on this case to see if can happens
            dbg("Parents list has invalid count {} !!!".format(parents))
            sys.exit(1)
        parent = self._gerrit.get_change_by_sha(parents[0]['commit'])
        if parent and parent.status not in ['MERGED', 'ABANDONED']:
            result.append(parent.id)
            result += parent.depends_on
        # collect Depends-On from commit message 
        msg = self._data['revisions'][self.revision]['commit']['message']
        for d in DEPENDS_RE.findall(msg):
            result.append(d.split(':')[1].strip())
        dbg("Change: %s: depends_on: %s" % (self._data['change_id'], result))
        return result


class Gerrit(object):
    def __init__(self, gerrit_url):
        self._url = gerrit_url.rstrip('/')
        self._session = Session(self._url)

    def _get_current_change(self, review_id, branch):
        params = 'q=change:%s' % review_id
        if branch:
            params += ' branch:%s' % branch
        params += '&o=CURRENT_COMMIT&o=CURRENT_REVISION'
        return self._session.get('/changes/', params=params)

    def get_changed_files(self, change):
        raw = self._session.get("/changes/%s/revisions/%s/files" %
            (change.id, change.revision_number))
        res = list()
        for k, _ in raw.items():
            if k != "/COMMIT_MSG":
                res.append(k)
        return res

    def get_current_change(self, review_id, branch=None):
        # request all branches for review_id to
        # allow cross branches dependencies between projects
        res = self._get_current_change(review_id, None)
        if len(res) == 1:
            # there is no ambiguite, so return the found change 
            return Change(res[0], self)
        # there is ambiquity - try to resolve it by branch
        for i in res:
            if i.get('branch') == branch:
                return Change(i, self)
        raise GerritRequestError("Review %s (branch=%s) not found" % (review_id, branch))

    def get_change_by_sha(self, sha):
        params = 'q=commit:%s&o=CURRENT_COMMIT&o=CURRENT_REVISION' % sha
        res = self._session.get('/changes/', params=params)
        if len(res) == 1:
            # there is no ambiguite, so return the found change 
            return Change(res[0], self)
        elif len(res) == 0:
            return None
        raise GerritRequestError("Search for SHA %s has too many results" % sha)


def resolve_dependencies(gerrit, change, parent_ids=[]):
    result = [ change ]
    parent_ids.append(change.change_id)
    depends_on_list = change.depends_on
    for i in depends_on_list:
        if i in parent_ids:
            raise DependencyLoopError(
                "There is dependency loop detected: id %s is already in %s" \
                % (i, parent_ids)
            )
        cc = gerrit.get_current_change(i, branch=change.branch)
        result += resolve_dependencies(gerrit, cc, copy.deepcopy(parent_ids))
    return result            


def resolve_files(gerrit, changes_list):
    for i in changes_list:
        i.set_files(gerrit.get_changed_files(i))
    return changes_list


def format_result(changes_list):
    res = list()
    for i in changes_list:
        item = {
            'id': i.change_id,
            'project': i.project,
            'ref': i.ref,
            'number': str(i.number),
            'branch': i.branch
        }
        if i.files:
            item['files'] = i.files
        res.append(item)
    return res


def main():
    parser = argparse.ArgumentParser(
        description="TF tool for Gerrit patchset dependencies resolving")
    parser.add_argument("--debug", dest="debug", action="store_true")
    parser.add_argument("--gerrit", help="Gerrit URL", dest="gerrit", type=str)
    parser.add_argument("--review", help="Review ID", dest="review", type=str)
    parser.add_argument("--branch", help="Branch", dest="branch", type=str)
    parser.add_argument("--changed_files", dest="changed_files", action="store_true")
    parser.add_argument("--output",
        help="Save result into the file instead stdout",
        default=None, dest="output", type=str)
    args = parser.parse_args()
    log_level = logging.DEBUG if args.debug else logging.INFO
    logging.basicConfig(level=log_level)
    try:
        gerrit = Gerrit(args.gerrit)
        change = gerrit.get_current_change(args.review, branch=args.branch)
        changes_list = resolve_dependencies(gerrit, change)
        changes_list.reverse()
        changes_list = collections.OrderedDict.fromkeys(changes_list)
        if args.changed_files:
            changes_list = resolve_files(gerrit, changes_list)
        result = format_result(changes_list)
        if args.output:
            with open(args.output, "w") as f:
                json.dump(result, f)
        else:
            print(json.dumps(result))
    except Exception as e:
        print(traceback.format_exc())
        err("ERROR: failed to resolve review dependencies: %s" % e)
        sys.exit(1)


if __name__ == "__main__":
    main()
