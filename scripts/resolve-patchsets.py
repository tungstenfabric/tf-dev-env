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

    def get(self, request, params = None):
        url = self._make_url(request)
        res = requests.get(url, params=params)
        if not res.ok:
            raise GerritRequestError("Failed request %s with code %s" % (res.url, res.status_code))
        response = res.text.strip(')]}\'')
        return json.loads(response)


class Change(object):
    def __init__(self, data):
        self._data = data
        dbg("Change: %s" % self._data)

    def __hash__(self):
        return hash(self.id)

    def __eq__(self, value):
        return self.id == value.id

    def __gt__(self, value):
        return self.id > value.id

    def __lt__(self, value):
        return self.id < value.id

    @property
    def project(self):
        return self._data['project']

    @property
    def branch(self):
        return self._data['branch']

    @property
    def id(self):
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
    def depends_on(self):
        result = []
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
        params='q=change:%s' % review_id
        if branch:
            params+=' branch:%s' % branch
        params+='&o=CURRENT_COMMIT&o=CURRENT_REVISION'
        return self._session.get('/changes/', params=params)

    def get_current_change(self, review_id, branch=None):
        res = self._get_current_change(review_id, None)
        for i in res:
            if i.get('branch') == branch:
                return Change(res[0])
        raise GerritRequestError("Review %s (branch=%s) not found" %(review_id, branch))


def resolve_dependencies(gerrit, change, parent_ids = []):
    result = [ change ]
    parent_ids.append(change.id)
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


def format_result(changes_list):
    res = list()
    for i in changes_list:
        res.append({'id': i.id, 'project': i.project, 'ref': i.ref, 'number': str(i.number)})
    return res


def main():
    parser = argparse.ArgumentParser(
        description="TF tool for Gerrit patchset dependencies resolving")
    parser.add_argument("--debug", dest="debug", action="store_true")
    parser.add_argument("--gerrit", help="Gerrit URL", dest="gerrit", type=str)
    parser.add_argument("--review", help="Review ID", dest="review", type=str)
    parser.add_argument("--branch", help="Branch", dest="branch", type=str)
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
