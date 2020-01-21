#!/usr/bin/env python

import argparse
import json
import logging
import os
import sys
import traceback
from xml.etree import ElementTree


def dbg(msg):
    logging.debug(msg)


def err(msg):
    logging.error(msg)


class Manifest(object):
    def __init__(self, file):
        if file:
            with open(file, 'r') as f:
                self._root = ElementTree.parse(f).getroot()
        else:
            self._root = ElementTree.fromstring('<manifest></manifest>')

    def set_remote(self, url):
        remotes = self._root.findall('.//remote')
        if remotes:
            for remote in remotes:
                ns = remote.get('fetch').split('/')[-1]
                u = url if not ns else "/".join([url, ns])
                remote.set('fetch', u)

    def set_branch_default(self, branch):
        defaults = self._root.findall('.//default')
        if defaults:
            for default in defaults:
                rev = default.get('revision').split('/')[:-1]
                rev.append(branch)
                b = branch if not rev else "/".join(rev)
                default.set('revision', b)

    def _apply_patch(self, patch):
        branch = patch.get('branch', None)
        if not branch:
            return
        project = patch['project']
        project_short = project.split('/')[-1]
        xpath = './/project[@name=\'%s\']' % project_short
        for p in self._root.findall(xpath):
            p.set('revision', branch)

    def apply_patches(self, patchsets):
        for p in patchsets:
            self._apply_patch(p)            

    def dump(self, file):
        if not file:
            ElementTree.dump(self._root)
            return
        with open(file, "w") as f:
            f.write(ElementTree.tostring(self._root, encoding='utf-8').decode('utf-8'))


def load_patchsets(file):
    with open(file, 'r') as f:
        return json.load(f)


def main():
    parser = argparse.ArgumentParser(
        description="TF tool for Gerrit patchset dependencies resolving")
    parser.add_argument("--debug", dest="debug", action="store_true")
    parser.add_argument("--source", help="Source file with manifest", dest="source", type=str)
    parser.add_argument("--remote", help="Remote to set in manifest", dest="remote", type=str)
    parser.add_argument("--branch", help="Branch", dest="branch", type=str, default=None)
    parser.add_argument("--patchsets", help="File with patchsets", dest="patchsets", type=str, default=None)
    parser.add_argument("--output",
        help="Save result into the file instead stdout",
        default=None, dest="output", type=str)
    args = parser.parse_args()
    log_level = logging.DEBUG if args.debug else logging.INFO
    logging.basicConfig(level=log_level)
    try:
        manifest = Manifest(args.source)
        if args.remote:
            manifest.set_remote(args.remote)
        if args.branch:
            manifest.set_branch_default(args.branch)
        if args.patchsets:
            manifest.apply_patches(load_patchsets(args.patchsets))

        manifest.dump(args.output)
    except Exception as e:
        print(traceback.format_exc())
        err("ERROR: failed patch manifest: %s" % e)
        sys.exit(1)


if __name__ == "__main__":
    main()
