2026-02-28T17:38:57.5341391Z Current runner version: '2.331.0'
2026-02-28T17:38:57.5366444Z ##[group]Runner Image Provisioner
2026-02-28T17:38:57.5367531Z Hosted Compute Agent
2026-02-28T17:38:57.5368281Z Version: 20260213.493
2026-02-28T17:38:57.5369068Z Commit: 5c115507f6dd24b8de37d8bbe0bb4509d0cc0fa3
2026-02-28T17:38:57.5369945Z Build Date: 2026-02-13T00:28:41Z
2026-02-28T17:38:57.5370830Z Worker ID: ***c8d2d228-ee87-4528-8bee-e1bfe7dc8bff***
2026-02-28T17:38:57.5371668Z Azure Region: westus3
2026-02-28T17:38:57.5372383Z ##[endgroup]
2026-02-28T17:38:57.5374516Z ##[group]Operating System
2026-02-28T17:38:57.5375228Z Ubuntu
2026-02-28T17:38:57.5375870Z 24.04.3
2026-02-28T17:38:57.5376501Z LTS
2026-02-28T17:38:57.5377136Z ##[endgroup]
2026-02-28T17:38:57.5377807Z ##[group]Runner Image
2026-02-28T17:38:57.5378587Z Image: ubuntu-24.04
2026-02-28T17:38:57.5379238Z Version: 20260224.36.1
2026-02-28T17:38:57.5380521Z Included Software: https://github.com/actions/runner-images/blob/ubuntu24/20260224.36/images/ubuntu/Ubuntu2404-Readme.md
2026-02-28T17:38:57.5382040Z Image Release: https://github.com/actions/runner-images/releases/tag/ubuntu24%2F20260224.36
2026-02-28T17:38:57.5383020Z ##[endgroup]
2026-02-28T17:38:57.5384460Z ##[group]GITHUB_TOKEN Permissions
2026-02-28T17:38:57.5386783Z Contents: write
2026-02-28T17:38:57.5387460Z Metadata: read
2026-02-28T17:38:57.5388068Z ##[endgroup]
2026-02-28T17:38:57.5390355Z Secret source: Actions
2026-02-28T17:38:57.5391383Z Prepare workflow directory
2026-02-28T17:38:57.5754809Z Prepare all required actions
2026-02-28T17:38:57.5792963Z Getting action download info
2026-02-28T17:38:58.1038917Z Download action repository 'actions/checkout@v4' (SHA:34e114876b0b11c390a56381ad16ebd13914f8d5)
2026-02-28T17:38:58.2191772Z Download action repository 'PaulHatch/semantic-version@v5.4.0' (SHA:a8f8f59fd7f0625188492e945240f12d7ad2dca3)
2026-02-28T17:38:58.8677883Z Download action repository 'actions/setup-java@v4' (SHA:c1e323688fd81a25caa38c78aa6df2d33d3e20d9)
2026-02-28T17:38:59.7787413Z Download action repository 'subosito/flutter-action@v2' (SHA:fd55f4c5af5b953cc57a2be44cb082c8f6635e8e)
2026-02-28T17:39:00.4535953Z Download action repository 'actions/cache@v4' (SHA:0057852bfaa89a56745cba8c7296529d2fc39830)
2026-02-28T17:39:00.5355560Z Download action repository 'actions/***-artifact@v4' (SHA:ea165f8d65b6e75b540449e92b4886f43607fa02)
2026-02-28T17:39:00.6224542Z Download action repository 'softprops/action-gh-release@v2' (SHA:a06a81a03ee405af7f2048a818ed3f03bbf83c7b)
2026-02-28T17:39:01.3297585Z Download action repository 'wzieba/Firebase-Distribution-Github-Action@v1' (SHA:bd494989dd4bec0343f78adee87fe66e48279ad6)
2026-02-28T17:39:01.9500061Z Getting action download info
2026-02-28T17:39:02.1707854Z Complete job name: Calculate Version & Build
2026-02-28T17:39:02.2203991Z ##[group]Pull down action image 'ghcr.io/wzieba/firebase-distribution-github-action:sha-344aa66'
2026-02-28T17:39:02.2243008Z ##[command]/usr/bin/docker pull ghcr.io/wzieba/firebase-distribution-github-action:sha-344aa66
2026-02-28T17:39:03.1000265Z sha-344aa66: Pulling from wzieba/firebase-distribution-github-action
2026-02-28T17:39:03.1000878Z 9621f1afde84: Pulling fs layer
2026-02-28T17:39:03.1001204Z b2ff27170c03: Pulling fs layer
2026-02-28T17:39:03.1001507Z 857f24243633: Pulling fs layer
2026-02-28T17:39:03.1001783Z f5234ba59f34: Pulling fs layer
2026-02-28T17:39:03.1002076Z ecca0f4797f0: Pulling fs layer
2026-02-28T17:39:03.1002353Z 81b25a48372d: Pulling fs layer
2026-02-28T17:39:03.1002636Z fd9b709cb1bb: Pulling fs layer
2026-02-28T17:39:03.1002926Z 4f4fb700ef54: Pulling fs layer
2026-02-28T17:39:03.1003412Z f5234ba59f34: Waiting
2026-02-28T17:39:03.1003725Z ecca0f4797f0: Waiting
2026-02-28T17:39:03.1003979Z 81b25a48372d: Waiting
2026-02-28T17:39:03.1004329Z fd9b709cb1bb: Waiting
2026-02-28T17:39:03.1004588Z 4f4fb700ef54: Waiting
2026-02-28T17:39:03.3699262Z 9621f1afde84: Verifying Checksum
2026-02-28T17:39:03.3705660Z 9621f1afde84: Download complete
2026-02-28T17:39:03.3795450Z 857f24243633: Download complete
2026-02-28T17:39:03.4793367Z 9621f1afde84: Pull complete
2026-02-28T17:39:03.4878113Z b2ff27170c03: Verifying Checksum
2026-02-28T17:39:03.4878787Z b2ff27170c03: Download complete
2026-02-28T17:39:03.5980545Z ecca0f4797f0: Verifying Checksum
2026-02-28T17:39:03.6020305Z ecca0f4797f0: Download complete
2026-02-28T17:39:03.6025286Z f5234ba59f34: Verifying Checksum
2026-02-28T17:39:03.6027334Z f5234ba59f34: Download complete
2026-02-28T17:39:03.7216947Z 81b25a48372d: Verifying Checksum
2026-02-28T17:39:03.7217895Z 81b25a48372d: Download complete
2026-02-28T17:39:03.8420901Z 4f4fb700ef54: Verifying Checksum
2026-02-28T17:39:03.8421826Z 4f4fb700ef54: Download complete
2026-02-28T17:39:04.2918501Z fd9b709cb1bb: Verifying Checksum
2026-02-28T17:39:04.2919187Z fd9b709cb1bb: Download complete
2026-02-28T17:39:05.4738648Z b2ff27170c03: Pull complete
2026-02-28T17:39:05.5327574Z 857f24243633: Pull complete
2026-02-28T17:39:05.5415371Z f5234ba59f34: Pull complete
2026-02-28T17:39:05.5481317Z ecca0f4797f0: Pull complete
2026-02-28T17:39:05.5662497Z 81b25a48372d: Pull complete
2026-02-28T17:39:15.6785621Z fd9b709cb1bb: Pull complete
2026-02-28T17:39:15.6859425Z 4f4fb700ef54: Pull complete
2026-02-28T17:39:15.6894986Z Digest: sha256:943e4685e86f1066f58ebf97ed54181aef36b618b72fb38e82d5693944507ef8
2026-02-28T17:39:15.6905287Z Status: Downloaded newer image for ghcr.io/wzieba/firebase-distribution-github-action:sha-344aa66
2026-02-28T17:39:15.6913678Z ghcr.io/wzieba/firebase-distribution-github-action:sha-344aa66
2026-02-28T17:39:15.6928400Z ##[endgroup]
2026-02-28T17:39:15.7192005Z ##[group]Run actions/checkout@v4
2026-02-28T17:39:15.7192585Z with:
2026-02-28T17:39:15.7192852Z   fetch-depth: 0
2026-02-28T17:39:15.7193366Z   repository: AlexisSisley/magic_compagnion
2026-02-28T17:39:15.7193842Z   token: ***
2026-02-28T17:39:15.7194088Z   ssh-strict: true
2026-02-28T17:39:15.7194345Z   ssh-user: git
2026-02-28T17:39:15.7194605Z   persist-credentials: true
2026-02-28T17:39:15.7194888Z   clean: true
2026-02-28T17:39:15.7195148Z   sparse-checkout-cone-mode: true
2026-02-28T17:39:15.7195470Z   fetch-tags: false
2026-02-28T17:39:15.7195720Z   show-progress: true
2026-02-28T17:39:15.7195983Z   lfs: false
2026-02-28T17:39:15.7196257Z   submodules: false
2026-02-28T17:39:15.7196509Z   set-safe-directory: true
2026-02-28T17:39:15.7197019Z ##[endgroup]
2026-02-28T17:39:15.8199718Z Syncing repository: AlexisSisley/magic_compagnion
2026-02-28T17:39:15.8201455Z ##[group]Getting Git version info
2026-02-28T17:39:15.8202054Z Working directory is '/home/runner/work/magic_compagnion/magic_compagnion'
2026-02-28T17:39:15.8202763Z [command]/usr/bin/git version
2026-02-28T17:39:15.8265856Z git version 2.53.0
2026-02-28T17:39:15.8288349Z ##[endgroup]
2026-02-28T17:39:15.8301715Z Temporarily overriding HOME='/home/runner/work/_temp/b3a248a4-1561-458e-86dc-e076ca365489' before making global git config changes
2026-02-28T17:39:15.8302728Z Adding repository directory to the temporary git global config as a safe directory
2026-02-28T17:39:15.8306939Z [command]/usr/bin/git config --global --add safe.directory /home/runner/work/magic_compagnion/magic_compagnion
2026-02-28T17:39:15.8342249Z Deleting the contents of '/home/runner/work/magic_compagnion/magic_compagnion'
2026-02-28T17:39:15.8345654Z ##[group]Initializing the repository
2026-02-28T17:39:15.8349517Z [command]/usr/bin/git init /home/runner/work/magic_compagnion/magic_compagnion
2026-02-28T17:39:15.8435737Z hint: Using 'master' as the name for the initial branch. This default branch name
2026-02-28T17:39:15.8436836Z hint: will change to "main" in Git 3.0. To configure the initial branch name
2026-02-28T17:39:15.8437765Z hint: to use in all of your new repositories, which will suppress this warning,
2026-02-28T17:39:15.8438497Z hint: call:
2026-02-28T17:39:15.8438900Z hint:
2026-02-28T17:39:15.8439397Z hint: 	git config --global init.defaultBranch <name>
2026-02-28T17:39:15.8440003Z hint:
2026-02-28T17:39:15.8440669Z hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
2026-02-28T17:39:15.8441618Z hint: 'development'. The just-created branch can be renamed via this command:
2026-02-28T17:39:15.8442234Z hint:
2026-02-28T17:39:15.8442501Z hint: 	git branch -m <name>
2026-02-28T17:39:15.8442785Z hint:
2026-02-28T17:39:15.8443330Z hint: Disable this message with "git config set advice.defaultBranchName false"
2026-02-28T17:39:15.8443987Z Initialized empty Git repository in /home/runner/work/magic_compagnion/magic_compagnion/.git/
2026-02-28T17:39:15.8451663Z [command]/usr/bin/git remote add origin https://github.com/AlexisSisley/magic_compagnion
2026-02-28T17:39:15.8482019Z ##[endgroup]
2026-02-28T17:39:15.8482493Z ##[group]Disabling automatic garbage collection
2026-02-28T17:39:15.8486101Z [command]/usr/bin/git config --local gc.auto 0
2026-02-28T17:39:15.8511158Z ##[endgroup]
2026-02-28T17:39:15.8511595Z ##[group]Setting up auth
2026-02-28T17:39:15.8517980Z [command]/usr/bin/git config --local --name-only --get-regexp core\.sshCommand
2026-02-28T17:39:15.8543933Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'core\.sshCommand' && git config --local --unset-all 'core.sshCommand' || :"
2026-02-28T17:39:15.8827738Z [command]/usr/bin/git config --local --name-only --get-regexp http\.https\:\/\/github\.com\/\.extraheader
2026-02-28T17:39:15.8852422Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'http\.https\:\/\/github\.com\/\.extraheader' && git config --local --unset-all 'http.https://github.com/.extraheader' || :"
2026-02-28T17:39:15.9027363Z [command]/usr/bin/git config --local --name-only --get-regexp ^includeIf\.gitdir:
2026-02-28T17:39:15.9061121Z [command]/usr/bin/git submodule foreach --recursive git config --local --show-origin --name-only --get-regexp remote.origin.url
2026-02-28T17:39:15.9244895Z [command]/usr/bin/git config --local http.https://github.com/.extraheader AUTHORIZATION: basic ***
2026-02-28T17:39:15.9275215Z ##[endgroup]
2026-02-28T17:39:15.9276123Z ##[group]Fetching the repository
2026-02-28T17:39:15.9284612Z [command]/usr/bin/git -c protocol.version=2 fetch --prune --no-recurse-submodules origin +refs/heads/*:refs/remotes/origin/* +refs/tags/*:refs/tags/*
2026-02-28T17:39:17.9583039Z From https://github.com/AlexisSisley/magic_compagnion
2026-02-28T17:39:17.9584012Z  * [new branch]      main           -> origin/main
2026-02-28T17:39:17.9584700Z  * [new branch]      release/v1.0.0 -> origin/release/v1.0.0
2026-02-28T17:39:17.9585279Z  * [new tag]         v0.1.2         -> v0.1.2
2026-02-28T17:39:17.9585873Z  * [new tag]         v0.1.3         -> v0.1.3
2026-02-28T17:39:17.9586425Z  * [new tag]         v0.1.4         -> v0.1.4
2026-02-28T17:39:17.9586959Z  * [new tag]         v0.2.0         -> v0.2.0
2026-02-28T17:39:17.9587499Z  * [new tag]         v0.2.1         -> v0.2.1
2026-02-28T17:39:17.9587951Z  * [new tag]         v0.2.2         -> v0.2.2
2026-02-28T17:39:17.9588267Z  * [new tag]         v1.0.0         -> v1.0.0
2026-02-28T17:39:17.9588576Z  * [new tag]         v1.0.1         -> v1.0.1
2026-02-28T17:39:17.9588908Z  * [new tag]         v1.0.10        -> v1.0.10
2026-02-28T17:39:17.9589236Z  * [new tag]         v1.0.11        -> v1.0.11
2026-02-28T17:39:17.9589553Z  * [new tag]         v1.0.12        -> v1.0.12
2026-02-28T17:39:17.9589867Z  * [new tag]         v1.0.13        -> v1.0.13
2026-02-28T17:39:17.9590180Z  * [new tag]         v1.0.14        -> v1.0.14
2026-02-28T17:39:17.9590534Z  * [new tag]         v1.0.15        -> v1.0.15
2026-02-28T17:39:17.9590862Z  * [new tag]         v1.0.16        -> v1.0.16
2026-02-28T17:39:17.9591177Z  * [new tag]         v1.0.17        -> v1.0.17
2026-02-28T17:39:17.9591500Z  * [new tag]         v1.0.18        -> v1.0.18
2026-02-28T17:39:17.9591813Z  * [new tag]         v1.0.19        -> v1.0.19
2026-02-28T17:39:17.9592132Z  * [new tag]         v1.0.2         -> v1.0.2
2026-02-28T17:39:17.9592459Z  * [new tag]         v1.0.20        -> v1.0.20
2026-02-28T17:39:17.9592773Z  * [new tag]         v1.0.21        -> v1.0.21
2026-02-28T17:39:17.9593089Z  * [new tag]         v1.0.23        -> v1.0.23
2026-02-28T17:39:17.9593779Z  * [new tag]         v1.0.25        -> v1.0.25
2026-02-28T17:39:17.9594104Z  * [new tag]         v1.0.26        -> v1.0.26
2026-02-28T17:39:17.9594424Z  * [new tag]         v1.0.28        -> v1.0.28
2026-02-28T17:39:17.9594742Z  * [new tag]         v1.0.29        -> v1.0.29
2026-02-28T17:39:17.9595165Z  * [new tag]         v1.0.3         -> v1.0.3
2026-02-28T17:39:17.9595491Z  * [new tag]         v1.0.30        -> v1.0.30
2026-02-28T17:39:17.9595819Z  * [new tag]         v1.0.31        -> v1.0.31
2026-02-28T17:39:17.9596151Z  * [new tag]         v1.0.32        -> v1.0.32
2026-02-28T17:39:17.9596472Z  * [new tag]         v1.0.4         -> v1.0.4
2026-02-28T17:39:17.9596863Z  * [new tag]         v1.0.5         -> v1.0.5
2026-02-28T17:39:17.9597208Z  * [new tag]         v1.0.6         -> v1.0.6
2026-02-28T17:39:17.9597539Z  * [new tag]         v1.0.7         -> v1.0.7
2026-02-28T17:39:17.9597849Z  * [new tag]         v1.0.8         -> v1.0.8
2026-02-28T17:39:17.9598166Z  * [new tag]         v1.0.9         -> v1.0.9
2026-02-28T17:39:17.9634947Z [command]/usr/bin/git branch --list --remote origin/main
2026-02-28T17:39:17.9656993Z   origin/main
2026-02-28T17:39:17.9663970Z [command]/usr/bin/git rev-parse refs/remotes/origin/main
2026-02-28T17:39:17.9684563Z d6b6f48d2670b73f16939bb6474287e8124a0170
2026-02-28T17:39:17.9688217Z ##[endgroup]
2026-02-28T17:39:17.9688707Z ##[group]Determining the checkout info
2026-02-28T17:39:17.9689559Z ##[endgroup]
2026-02-28T17:39:17.9694178Z [command]/usr/bin/git sparse-checkout disable
2026-02-28T17:39:17.9722673Z [command]/usr/bin/git config --local --unset-all extensions.worktreeConfig
2026-02-28T17:39:17.9743641Z ##[group]Checking out the ref
2026-02-28T17:39:17.9747529Z [command]/usr/bin/git checkout --progress --force -B main refs/remotes/origin/main
2026-02-28T17:39:18.2344431Z Switched to a new branch 'main'
2026-02-28T17:39:18.2344934Z branch 'main' set up to track 'origin/main'.
2026-02-28T17:39:18.2361218Z ##[endgroup]
2026-02-28T17:39:18.2396669Z [command]/usr/bin/git log -1 --format=%H
2026-02-28T17:39:18.2417491Z d6b6f48d2670b73f16939bb6474287e8124a0170
2026-02-28T17:39:18.2604057Z ##[group]Run PaulHatch/semantic-version@v5.4.0
2026-02-28T17:39:18.2604400Z with:
2026-02-28T17:39:18.2604631Z   tag_prefix: v
2026-02-28T17:39:18.2604958Z   version_format: $***major***.$***minor***.$***patch***
2026-02-28T17:39:18.2605395Z   major_pattern: (refactor|BREAKING CHANGE|Mise à jour majeure)
2026-02-28T17:39:18.2605865Z   minor_pattern: (feat|Feat|feature|Feature|Ajout|New|Nouvelle|Mise à jour)
2026-02-28T17:39:18.2606281Z   bump_each_commit: true
2026-02-28T17:39:18.2606551Z   search_commit_body: true
2026-02-28T17:39:18.2606819Z   user_format_type: csv
2026-02-28T17:39:18.2607083Z   branch: HEAD
2026-02-28T17:39:18.2607324Z   use_branches: false
2026-02-28T17:39:18.2607579Z   version_from_branch: false
2026-02-28T17:39:18.2607865Z   enable_prerelease_mode: false
2026-02-28T17:39:18.2608141Z   debug: false
2026-02-28T17:39:18.2608393Z ##[endgroup]
2026-02-28T17:39:18.3316523Z Version is 1.0.34
2026-02-28T17:39:18.3318062Z To create a release for this version, go to https://github.com/AlexisSisley/magic_compagnion/releases/new?tag=v1.0.34&target=d6b6f48d2670b73f16939bb6474287e8124a0170
2026-02-28T17:39:18.3472842Z ##[group]Run actions/setup-java@v4
2026-02-28T17:39:18.3473303Z with:
2026-02-28T17:39:18.3473550Z   distribution: temurin
2026-02-28T17:39:18.3473815Z   java-version: 17
2026-02-28T17:39:18.3474058Z   java-package: jdk
2026-02-28T17:39:18.3474301Z   check-latest: false
2026-02-28T17:39:18.3474552Z   server-id: github
2026-02-28T17:39:18.3474799Z   server-username: GITHUB_ACTOR
2026-02-28T17:39:18.3475089Z   server-password: GITHUB_TOKEN
2026-02-28T17:39:18.3475380Z   overwrite-settings: true
2026-02-28T17:39:18.3475647Z   job-status: success
2026-02-28T17:39:18.3476000Z   token: ***
2026-02-28T17:39:18.3476243Z ##[endgroup]
2026-02-28T17:39:18.5343551Z ##[group]Installed distributions
2026-02-28T17:39:18.5645109Z Resolved Java 17.0.18+8 from tool-cache
2026-02-28T17:39:18.5646149Z Setting Java 17.0.18+8 as the default
2026-02-28T17:39:18.5661912Z Creating toolchains.xml for JDK version 17 from temurin
2026-02-28T17:39:18.5773491Z Writing to /home/runner/.m2/toolchains.xml
2026-02-28T17:39:18.5774070Z 
2026-02-28T17:39:18.5774440Z Java configuration:
2026-02-28T17:39:18.5776023Z   Distribution: temurin
2026-02-28T17:39:18.5776483Z   Version: 17.0.18+8
2026-02-28T17:39:18.5777096Z   Path: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:39:18.5777607Z 
2026-02-28T17:39:18.5778291Z ##[endgroup]
2026-02-28T17:39:18.5794060Z Creating settings.xml with server-id: github
2026-02-28T17:39:18.5807810Z Writing to /home/runner/.m2/settings.xml
2026-02-28T17:39:18.6016759Z ##[group]Run subosito/flutter-action@v2
2026-02-28T17:39:18.6017095Z with:
2026-02-28T17:39:18.6017328Z   channel: stable
2026-02-28T17:39:18.6017575Z   cache: true
2026-02-28T17:39:18.6017817Z   architecture: X64
2026-02-28T17:39:18.6018071Z   pub-cache-path: default
2026-02-28T17:39:18.6018358Z   dry-run: false
2026-02-28T17:39:18.6018671Z   git-source: https://github.com/flutter/flutter.git
2026-02-28T17:39:18.6019002Z env:
2026-02-28T17:39:18.6019336Z   JAVA_HOME: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:39:18.6019844Z   JAVA_HOME_17_X64: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:39:18.6020253Z ##[endgroup]
2026-02-28T17:39:18.6108546Z ##[group]Run chmod +x "$GITHUB_ACTION_PATH/setup.sh"
2026-02-28T17:39:18.6109083Z [36;1mchmod +x "$GITHUB_ACTION_PATH/setup.sh"[0m
2026-02-28T17:39:18.6141916Z shell: /usr/bin/bash --noprofile --norc -e -o pipefail ***0***
2026-02-28T17:39:18.6142313Z env:
2026-02-28T17:39:18.6142722Z   JAVA_HOME: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:39:18.6143399Z   JAVA_HOME_17_X64: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:39:18.6143817Z ##[endgroup]
2026-02-28T17:39:18.6266958Z ##[group]Run $GITHUB_ACTION_PATH/setup.sh -p \
2026-02-28T17:39:18.6267382Z [36;1m$GITHUB_ACTION_PATH/setup.sh -p \[0m
2026-02-28T17:39:18.6267695Z [36;1m  -n '' \[0m
2026-02-28T17:39:18.6267936Z [36;1m  -f '' \[0m
2026-02-28T17:39:18.6268177Z [36;1m  -a 'X64' \[0m
2026-02-28T17:39:18.6268423Z [36;1m  -k '' \[0m
2026-02-28T17:39:18.6268653Z [36;1m  -c '' \[0m
2026-02-28T17:39:18.6268888Z [36;1m  -l '' \[0m
2026-02-28T17:39:18.6269123Z [36;1m  -d 'default' \[0m
2026-02-28T17:39:18.6269466Z [36;1m  -g 'https://github.com/flutter/flutter.git' \[0m
2026-02-28T17:39:18.6269808Z [36;1m  stable[0m
2026-02-28T17:39:18.6295920Z shell: /usr/bin/bash --noprofile --norc -e -o pipefail ***0***
2026-02-28T17:39:18.6296305Z env:
2026-02-28T17:39:18.6296682Z   JAVA_HOME: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:39:18.6297200Z   JAVA_HOME_17_X64: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:39:18.6297618Z ##[endgroup]
2026-02-28T17:39:18.8132636Z ##[group]Run actions/cache@v4
2026-02-28T17:39:18.8132958Z with:
2026-02-28T17:39:18.8133763Z   path: /opt/hostedtoolcache/flutter/stable-3.41.2-x64
2026-02-28T17:39:18.8134267Z   key: flutter-linux-stable-3.41.2-x64-90673a4eef275d1a6692c26ac80d6d746d41a73a
2026-02-28T17:39:18.8134735Z   enableCrossOsArchive: false
2026-02-28T17:39:18.8135027Z   fail-on-cache-miss: false
2026-02-28T17:39:18.8135298Z   lookup-only: false
2026-02-28T17:39:18.8135546Z   save-always: false
2026-02-28T17:39:18.8135788Z env:
2026-02-28T17:39:18.8136111Z   JAVA_HOME: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:39:18.8136612Z   JAVA_HOME_17_X64: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:39:18.8137021Z ##[endgroup]
2026-02-28T17:39:19.1571294Z Cache not found for input keys: flutter-linux-stable-3.41.2-x64-90673a4eef275d1a6692c26ac80d6d746d41a73a
2026-02-28T17:39:19.2572098Z ##[group]Run actions/cache@v4
2026-02-28T17:39:19.2572389Z with:
2026-02-28T17:39:19.2572637Z   path: /home/runner/.pub-cache
2026-02-28T17:39:19.2573820Z   key: flutter-pub-linux-stable-3.41.2-x64-90673a4eef275d1a6692c26ac80d6d746d41a73a-04ef08067b29bcfa25eda15d9d7db77bf825e0df40bef70fe72efbeb35b41332
2026-02-28T17:39:19.2574585Z   enableCrossOsArchive: false
2026-02-28T17:39:19.2574878Z   fail-on-cache-miss: false
2026-02-28T17:39:19.2575157Z   lookup-only: false
2026-02-28T17:39:19.2575412Z   save-always: false
2026-02-28T17:39:19.2575646Z env:
2026-02-28T17:39:19.2575980Z   JAVA_HOME: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:39:19.2576498Z   JAVA_HOME_17_X64: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:39:19.2576901Z ##[endgroup]
2026-02-28T17:39:19.5942455Z Cache not found for input keys: flutter-pub-linux-stable-3.41.2-x64-90673a4eef275d1a6692c26ac80d6d746d41a73a-04ef08067b29bcfa25eda15d9d7db77bf825e0df40bef70fe72efbeb35b41332
2026-02-28T17:39:19.6013456Z ##[group]Run $GITHUB_ACTION_PATH/setup.sh \
2026-02-28T17:39:19.6013951Z [36;1m$GITHUB_ACTION_PATH/setup.sh \[0m
2026-02-28T17:39:19.6014291Z [36;1m  -n '3.41.2' \[0m
2026-02-28T17:39:19.6014560Z [36;1m  -a 'x64' \[0m
2026-02-28T17:39:19.6014915Z [36;1m  -c '/opt/hostedtoolcache/flutter/stable-3.41.2-x64' \[0m
2026-02-28T17:39:19.6015319Z [36;1m  -d '/home/runner/.pub-cache' \[0m
2026-02-28T17:39:19.6015620Z [36;1m  stable[0m
2026-02-28T17:39:19.6042468Z shell: /usr/bin/bash --noprofile --norc -e -o pipefail ***0***
2026-02-28T17:39:19.6042857Z env:
2026-02-28T17:39:19.6043311Z   JAVA_HOME: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:39:19.6043853Z   JAVA_HOME_17_X64: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:39:19.6044277Z ##[endgroup]
2026-02-28T17:39:19.8181659Z   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
2026-02-28T17:39:19.8183014Z                                  Dload  Upload   Total   Spent    Left  Speed
2026-02-28T17:39:19.8184456Z 
2026-02-28T17:39:20.0924478Z   0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
2026-02-28T17:39:21.0925395Z   1 1446M    1 25.0M    0     0  91.4M      0  0:00:15 --:--:--  0:00:15 91.2M
2026-02-28T17:39:22.0927215Z  16 1446M   16  235M    0     0   184M      0  0:00:07  0:00:01  0:00:06  184M
2026-02-28T17:39:23.0924224Z  30 1446M   30  435M    0     0   191M      0  0:00:07  0:00:02  0:00:05  191M
2026-02-28T17:39:24.0925355Z  43 1446M   43  625M    0     0   191M      0  0:00:07  0:00:03  0:00:04  190M
2026-02-28T17:39:25.0926477Z  56 1446M   56  824M    0     0   192M      0  0:00:07  0:00:04  0:00:03  192M
2026-02-28T17:39:26.0934068Z  71 1446M   71 1029M    0     0   195M      0  0:00:07  0:00:05  0:00:02  200M
2026-02-28T17:39:26.9519088Z  86 1446M   86 1256M    0     0   200M      0  0:00:07  0:00:06  0:00:01  204M
2026-02-28T17:39:26.9519682Z 100 1446M  100 1446M    0     0   202M      0  0:00:07  0:00:07 --:--:--  208M
2026-02-28T17:40:19.2796105Z ##[group]Run actions/cache@v4
2026-02-28T17:40:19.2796510Z with:
2026-02-28T17:40:19.2796808Z   path: ~/.gradle/caches
~/.gradle/wrapper

2026-02-28T17:40:19.2797312Z   key: Linux-gradle-1f4bb7f831f1a5d0844f968aeb38b1def1fc9b83c64113001c87f7e297fb7589
2026-02-28T17:40:19.2797797Z   restore-keys: Linux-gradle-

2026-02-28T17:40:19.2798092Z   enableCrossOsArchive: false
2026-02-28T17:40:19.2798387Z   fail-on-cache-miss: false
2026-02-28T17:40:19.2798664Z   lookup-only: false
2026-02-28T17:40:19.2798914Z   save-always: false
2026-02-28T17:40:19.2799150Z env:
2026-02-28T17:40:19.2799488Z   JAVA_HOME: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:40:19.2799992Z   JAVA_HOME_17_X64: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:40:19.2800473Z   FLUTTER_ROOT: /opt/hostedtoolcache/flutter/stable-3.41.2-x64
2026-02-28T17:40:19.2800860Z   PUB_CACHE: /home/runner/.pub-cache
2026-02-28T17:40:19.2801155Z ##[endgroup]
2026-02-28T17:40:19.6231486Z Cache not found for input keys: Linux-gradle-1f4bb7f831f1a5d0844f968aeb38b1def1fc9b83c64113001c87f7e297fb7589, Linux-gradle-
2026-02-28T17:40:19.6286130Z ##[group]Run flutter pub get
2026-02-28T17:40:19.6286460Z [36;1mflutter pub get[0m
2026-02-28T17:40:19.6314923Z shell: /usr/bin/bash -e ***0***
2026-02-28T17:40:19.6315236Z env:
2026-02-28T17:40:19.6315583Z   JAVA_HOME: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:40:19.6316101Z   JAVA_HOME_17_X64: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:40:19.6316596Z   FLUTTER_ROOT: /opt/hostedtoolcache/flutter/stable-3.41.2-x64
2026-02-28T17:40:19.6316985Z   PUB_CACHE: /home/runner/.pub-cache
2026-02-28T17:40:19.6317278Z ##[endgroup]
2026-02-28T17:40:22.3884835Z Resolving dependencies...
2026-02-28T17:40:23.2308811Z Downloading packages...
2026-02-28T17:40:29.9114149Z > _fe_analyzer_shared 91.0.0 (was 85.0.0) (97.0.0 available)
2026-02-28T17:40:29.9114906Z > analyzer 8.4.1 (was 7.7.1) (11.0.0 available)
2026-02-28T17:40:29.9115472Z   archive 4.0.7 (4.0.9 available)
2026-02-28T17:40:29.9115850Z   build 3.1.0 (4.0.4 available)
2026-02-28T17:40:29.9116225Z   build_config 1.2.0 (1.3.0 available)
2026-02-28T17:40:29.9116707Z   build_resolvers 3.0.3 (3.0.4 available)
2026-02-28T17:40:29.9117398Z   build_runner 2.7.1 (2.11.1 available)
2026-02-28T17:40:29.9117854Z   build_runner_core 9.3.1 (9.3.2 available)
2026-02-28T17:40:29.9118340Z   camera 0.11.3 (0.12.0 available)
2026-02-28T17:40:29.9118874Z   camera_android_camerax 0.6.24+1 (0.7.0+1 available)
2026-02-28T17:40:29.9119479Z   camera_avfoundation 0.9.22+4 (0.10.0+3 available)
2026-02-28T17:40:29.9120044Z   camera_web 0.3.5 (0.3.5+3 available)
2026-02-28T17:40:29.9120564Z > characters 1.4.1 (was 1.4.0)
2026-02-28T17:40:29.9121035Z   cloud_functions 5.6.2 (6.0.6 available)
2026-02-28T17:40:29.9121679Z   cloud_functions_platform_interface 5.8.2 (5.8.9 available)
2026-02-28T17:40:29.9122358Z   cloud_functions_web 4.11.5 (5.1.2 available)
2026-02-28T17:40:29.9122879Z   cross_file 0.3.5 (0.3.5+2 available)
2026-02-28T17:40:29.9123608Z > dart_style 3.1.3 (was 3.1.1) (3.1.6 available)
2026-02-28T17:40:29.9124223Z   dbus 0.7.11 (0.7.12 available)
2026-02-28T17:40:29.9124712Z   dio 5.9.0 (5.9.1 available)
2026-02-28T17:40:29.9125196Z   drift 2.29.0 (2.31.0 available)
2026-02-28T17:40:29.9125700Z   drift_dev 2.29.0 (2.31.0 available)
2026-02-28T17:40:29.9126222Z   drift_flutter 0.2.7 (0.2.8 available)
2026-02-28T17:40:29.9126741Z   equatable 2.0.7 (2.0.8 available)
2026-02-28T17:40:29.9127375Z   extension_google_sign_in_as_googleapis_auth 2.0.13 (3.0.0 available)
2026-02-28T17:40:29.9128088Z   ffi 2.1.4 (2.2.0 available)
2026-02-28T17:40:29.9128510Z   file_picker 10.3.7 (10.3.10 available)
2026-02-28T17:40:29.9129012Z   firebase_core 3.15.2 (4.4.0 available)
2026-02-28T17:40:29.9129515Z   firebase_core_web 2.24.1 (3.4.0 available)
2026-02-28T17:40:29.9130036Z   fl_chart 0.68.0 (1.1.1 available)
2026-02-28T17:40:29.9130644Z   flutter_markdown 0.7.7+1 (discontinued replaced by flutter_markdown_plus)
2026-02-28T17:40:29.9131390Z   flutter_plugin_android_lifecycle 2.0.32 (2.0.33 available)
2026-02-28T17:40:29.9132033Z   flutter_riverpod 3.0.3 (3.2.1 available)
2026-02-28T17:40:29.9132547Z   flutter_svg 2.2.2 (2.2.3 available)
2026-02-28T17:40:29.9133001Z   google_fonts 6.3.2 (8.0.2 available)
2026-02-28T17:40:29.9133533Z ! google_mlkit_commons 0.11.0 (overridden) (0.11.1 available)
2026-02-28T17:40:29.9133972Z ! google_mlkit_text_recognition 0.15.0 (overridden) (0.15.1 available)
2026-02-28T17:40:29.9134359Z   google_sign_in 6.3.0 (7.2.0 available)
2026-02-28T17:40:29.9134682Z   google_sign_in_android 6.2.1 (7.2.9 available)
2026-02-28T17:40:29.9135024Z   google_sign_in_ios 5.9.0 (6.3.0 available)
2026-02-28T17:40:29.9135385Z   google_sign_in_platform_interface 2.5.0 (3.1.0 available)
2026-02-28T17:40:29.9135757Z   google_sign_in_web 0.12.4+4 (1.1.2 available)
2026-02-28T17:40:29.9136087Z   googleapis 11.4.0 (16.0.0 available)
2026-02-28T17:40:29.9136395Z   googleapis_auth 2.0.0 (2.1.0 available)
2026-02-28T17:40:29.9136701Z   image 4.5.4 (4.8.0 available)
2026-02-28T17:40:29.9137427Z   image_picker_android 0.8.13+10 (0.8.13+14 available)
2026-02-28T17:40:29.9138173Z   image_picker_ios 0.8.13+2 (0.8.13+6 available)
2026-02-28T17:40:29.9138731Z   json_annotation 4.9.0 (4.11.0 available)
2026-02-28T17:40:29.9139208Z   lints 6.0.0 (6.1.0 available)
2026-02-28T17:40:29.9139536Z > matcher 0.12.18 (was 0.12.17) (0.12.19 available)
2026-02-28T17:40:29.9139885Z > material_color_utilities 0.13.0 (was 0.11.1)
2026-02-28T17:40:29.9140226Z > meta 1.17.0 (was 1.16.0) (1.18.1 available)
2026-02-28T17:40:29.9140570Z   package_info_plus 8.3.1 (9.0.0 available)
2026-02-28T17:40:29.9140912Z   path_provider_android 2.2.20 (2.2.22 available)
2026-02-28T17:40:29.9141274Z   path_provider_foundation 2.4.3 (2.6.0 available)
2026-02-28T17:40:29.9141614Z   petitparser 7.0.1 (7.0.2 available)
2026-02-28T17:40:29.9141922Z   posix 6.0.3 (6.5.0 available)
2026-02-28T17:40:29.9142203Z   riverpod 3.0.3 (3.2.1 available)
2026-02-28T17:40:29.9142509Z   shared_preferences 2.5.3 (2.5.4 available)
2026-02-28T17:40:29.9142878Z   shared_preferences_android 2.4.15 (2.4.21 available)
2026-02-28T17:40:29.9143394Z   shared_preferences_foundation 2.5.5 (2.5.6 available)
2026-02-28T17:40:29.9143740Z   source_gen 4.0.0 (4.2.0 available)
2026-02-28T17:40:29.9144046Z   source_span 1.10.1 (1.10.2 available)
2026-02-28T17:40:29.9144361Z   sqlite3 2.9.4 (3.1.6 available)
2026-02-28T17:40:29.9144680Z   sqlite3_flutter_libs 0.5.41 (0.6.0+eol available)
2026-02-28T17:40:29.9145044Z   sqlparser 0.42.1 (0.43.1 available)
2026-02-28T17:40:29.9145423Z > test 1.29.0 (was 1.26.2) (1.30.0 available)
2026-02-28T17:40:29.9145755Z > test_api 0.7.9 (was 0.7.6) (0.7.10 available)
2026-02-28T17:40:29.9146094Z > test_core 0.6.15 (was 0.6.11) (0.6.16 available)
2026-02-28T17:40:29.9146432Z   universal_io 2.2.2 (2.3.1 available)
2026-02-28T17:40:29.9146740Z   url_launcher_ios 6.3.6 (6.4.1 available)
2026-02-28T17:40:29.9147059Z   url_launcher_linux 3.2.1 (3.2.2 available)
2026-02-28T17:40:29.9147383Z   url_launcher_web 2.4.1 (2.4.2 available)
2026-02-28T17:40:29.9147760Z   url_launcher_windows 3.1.4 (3.1.5 available)
2026-02-28T17:40:29.9148080Z   uuid 4.5.2 (4.5.3 available)
2026-02-28T17:40:29.9148427Z   vector_graphics_compiler 1.1.19 (1.2.0 available)
2026-02-28T17:40:29.9148764Z   wakelock_plus 1.3.3 (1.4.0 available)
2026-02-28T17:40:29.9149065Z   watcher 1.1.4 (1.2.1 available)
2026-02-28T17:40:29.9149351Z   win32 5.15.0 (6.0.0 available)
2026-02-28T17:40:29.9149674Z These packages are no longer being depended on:
2026-02-28T17:40:29.9150288Z - js 0.7.2
2026-02-28T17:40:29.9150689Z Changed 11 dependencies!
2026-02-28T17:40:29.9151164Z 1 package is discontinued.
2026-02-28T17:40:29.9151813Z 76 packages have newer versions incompatible with dependency constraints.
2026-02-28T17:40:29.9152442Z Try `flutter pub outdated` for more information.
2026-02-28T17:40:30.6995047Z ##[group]Run flutter analyze --no-fatal-infos
2026-02-28T17:40:30.6995456Z [36;1mflutter analyze --no-fatal-infos[0m
2026-02-28T17:40:30.7022459Z shell: /usr/bin/bash -e ***0***
2026-02-28T17:40:30.7022791Z env:
2026-02-28T17:40:30.7023390Z   JAVA_HOME: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:40:30.7023927Z   JAVA_HOME_17_X64: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.18-8/x64
2026-02-28T17:40:30.7024421Z   FLUTTER_ROOT: /opt/hostedtoolcache/flutter/stable-3.41.2-x64
2026-02-28T17:40:30.7024811Z   PUB_CACHE: /home/runner/.pub-cache
2026-02-28T17:40:30.7025115Z ##[endgroup]
2026-02-28T17:40:57.4403513Z Analyzing magic_compagnion...                                   
2026-02-28T17:40:57.4409948Z 
2026-02-28T17:40:57.4469660Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:35:25 • prefer_single_quotes
2026-02-28T17:40:57.4470999Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:50:27 • prefer_single_quotes
2026-02-28T17:40:57.4472210Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:105:21 • prefer_single_quotes
2026-02-28T17:40:57.4473508Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:112:17 • prefer_single_quotes
2026-02-28T17:40:57.4476732Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:126:26 • prefer_single_quotes
2026-02-28T17:40:57.4477987Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:128:26 • prefer_single_quotes
2026-02-28T17:40:57.4479199Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:129:26 • prefer_single_quotes
2026-02-28T17:40:57.4480419Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:130:26 • prefer_single_quotes
2026-02-28T17:40:57.4481605Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:140:31 • prefer_single_quotes
2026-02-28T17:40:57.4482812Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:146:34 • prefer_single_quotes
2026-02-28T17:40:57.4484144Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:149:25 • prefer_single_quotes
2026-02-28T17:40:57.4485332Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:168:21 • prefer_single_quotes
2026-02-28T17:40:57.4486983Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/chat_screen.dart:169:39 • deprecated_member_use
2026-02-28T17:40:57.4488927Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/chat_screen.dart:223:50 • deprecated_member_use
2026-02-28T17:40:57.4490846Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/chat_screen.dart:223:95 • deprecated_member_use
2026-02-28T17:40:57.4492771Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/chat_screen.dart:224:50 • deprecated_member_use
2026-02-28T17:40:57.4494660Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/chat_screen.dart:224:93 • deprecated_member_use
2026-02-28T17:40:57.4496528Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/chat_screen.dart:225:54 • deprecated_member_use
2026-02-28T17:40:57.4498528Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/chat_screen.dart:225:86 • deprecated_member_use
2026-02-28T17:40:57.4500569Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/chat_screen.dart:243:43 • deprecated_member_use
2026-02-28T17:40:57.4502175Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:252:24 • prefer_single_quotes
2026-02-28T17:40:57.4503911Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/chat_screen.dart:285:44 • deprecated_member_use
2026-02-28T17:40:57.4506552Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/chat_screen.dart:298:45 • deprecated_member_use
2026-02-28T17:40:57.4508534Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/chat_screen.dart:300:74 • deprecated_member_use
2026-02-28T17:40:57.4510053Z    info • Unnecessary use of double quotes • lib/chat_screen.dart:306:37 • prefer_single_quotes
2026-02-28T17:40:57.4511594Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/chat_screen.dart:307:68 • deprecated_member_use
2026-02-28T17:40:57.4513754Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/chat_screen.dart:326:67 • deprecated_member_use
2026-02-28T17:40:57.4515745Z    info • Use 'const' with the constructor to improve performance • lib/controllers/card_search_controller.dart:48:41 • prefer_const_constructors
2026-02-28T17:40:57.4517507Z    info • Unnecessary use of double quotes • lib/controllers/card_search_controller.dart:99:14 • prefer_single_quotes
2026-02-28T17:40:57.4519112Z    info • Unnecessary use of double quotes • lib/controllers/card_search_controller.dart:101:12 • prefer_single_quotes
2026-02-28T17:40:57.4520982Z    info • Unnecessary use of double quotes • lib/controllers/card_search_controller.dart:237:24 • prefer_single_quotes
2026-02-28T17:40:57.4522607Z    info • Unnecessary use of double quotes • lib/controllers/card_search_controller.dart:262:24 • prefer_single_quotes
2026-02-28T17:40:57.4524440Z    info • Unnecessary use of double quotes • lib/controllers/card_search_controller.dart:268:15 • prefer_single_quotes
2026-02-28T17:40:57.4526243Z    info • Use 'const' with the constructor to improve performance • lib/controllers/card_search_controller.dart:437:22 • prefer_const_constructors
2026-02-28T17:40:57.4528066Z    info • Unnecessary use of double quotes • lib/controllers/card_search_controller.dart:441:22 • prefer_single_quotes
2026-02-28T17:40:57.4529911Z    info • Statements in an if should be enclosed in a block • lib/controllers/collection_controller.dart:189:32 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4532000Z    info • Statements in an if should be enclosed in a block • lib/controllers/collection_controller.dart:190:14 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4537735Z    info • Statements in an if should be enclosed in a block • lib/controllers/collection_controller.dart:220:21 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4538975Z    info • Statements in an if should be enclosed in a block • lib/controllers/collection_controller.dart:221:14 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4540181Z    info • Unnecessary use of double quotes • lib/controllers/collection_controller.dart:338:25 • prefer_single_quotes
2026-02-28T17:40:57.4541149Z    info • Unnecessary use of double quotes • lib/controllers/collection_controller.dart:348:16 • prefer_single_quotes
2026-02-28T17:40:57.4542204Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:220:20 • prefer_single_quotes
2026-02-28T17:40:57.4543290Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:282:22 • prefer_single_quotes
2026-02-28T17:40:57.4544339Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:297:16 • prefer_single_quotes
2026-02-28T17:40:57.4545759Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:388:16 • prefer_single_quotes
2026-02-28T17:40:57.4547337Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:389:16 • prefer_single_quotes
2026-02-28T17:40:57.4548844Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:390:16 • prefer_single_quotes
2026-02-28T17:40:57.4550704Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:394:18 • prefer_single_quotes
2026-02-28T17:40:57.4551687Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:395:18 • prefer_single_quotes
2026-02-28T17:40:57.4552725Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:399:18 • prefer_single_quotes
2026-02-28T17:40:57.4553924Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:401:54 • prefer_single_quotes
2026-02-28T17:40:57.4554827Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:403:16 • prefer_single_quotes
2026-02-28T17:40:57.4555903Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:406:20 • prefer_single_quotes
2026-02-28T17:40:57.4557399Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:409:16 • prefer_single_quotes
2026-02-28T17:40:57.4558927Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:412:18 • prefer_single_quotes
2026-02-28T17:40:57.4560415Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:414:20 • prefer_single_quotes
2026-02-28T17:40:57.4562096Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:426:16 • prefer_single_quotes
2026-02-28T17:40:57.4563695Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:427:16 • prefer_single_quotes
2026-02-28T17:40:57.4565219Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:429:18 • prefer_single_quotes
2026-02-28T17:40:57.4566715Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:439:16 • prefer_single_quotes
2026-02-28T17:40:57.4568232Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:440:16 • prefer_single_quotes
2026-02-28T17:40:57.4569823Z    info • Unnecessary use of double quotes • lib/controllers/deck_detail_controller.dart:442:18 • prefer_single_quotes
2026-02-28T17:40:57.4571320Z    info • Unnecessary use of double quotes • lib/controllers/deck_list_controller.dart:229:15 • prefer_single_quotes
2026-02-28T17:40:57.4573038Z    info • Statements in an if should be enclosed in a block • lib/controllers/deck_list_controller.dart:253:31 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4574893Z    info • Statements in an if should be enclosed in a block • lib/controllers/deck_list_controller.dart:254:37 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4575909Z    info • Statements in an if should be enclosed in a block • lib/controllers/deck_list_controller.dart:255:14 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4576813Z    info • Unnecessary use of double quotes • lib/controllers/deck_list_controller.dart:265:25 • prefer_single_quotes
2026-02-28T17:40:57.4577631Z    info • Unnecessary use of double quotes • lib/controllers/deck_list_controller.dart:298:110 • prefer_single_quotes
2026-02-28T17:40:57.4578547Z    info • Use 'const' with the constructor to improve performance • lib/controllers/set_detail_controller.dart:73:41 • prefer_const_constructors
2026-02-28T17:40:57.4579579Z    info • Statements in a for should be enclosed in a block • lib/controllers/set_detail_controller.dart:151:24 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4580613Z    info • Statements in a for should be enclosed in a block • lib/controllers/set_detail_controller.dart:157:30 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4581516Z    info • Unnecessary use of double quotes • lib/controllers/set_detail_controller.dart:379:57 • prefer_single_quotes
2026-02-28T17:40:57.4582327Z    info • Unnecessary use of double quotes • lib/controllers/set_detail_controller.dart:413:57 • prefer_single_quotes
2026-02-28T17:40:57.4583222Z    info • Unnecessary use of double quotes • lib/controllers/set_detail_controller.dart:445:57 • prefer_single_quotes
2026-02-28T17:40:57.4584180Z    info • Unnecessary use of double quotes • lib/controllers/set_detail_controller.dart:481:57 • prefer_single_quotes
2026-02-28T17:40:57.4585127Z    info • Statements in a for should be enclosed in a block • lib/controllers/set_detail_controller.dart:515:24 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4586162Z    info • Statements in a for should be enclosed in a block • lib/controllers/set_detail_controller.dart:520:30 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4587161Z    info • Statements in an if should be enclosed in a block • lib/data/database/app_database.dart:200:34 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4588152Z    info • Statements in an if should be enclosed in a block • lib/data/database/app_database.dart:201:42 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4589133Z    info • Statements in an if should be enclosed in a block • lib/data/database/app_database.dart:217:34 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4590095Z    info • Statements in an if should be enclosed in a block • lib/data/database/app_database.dart:218:42 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4591063Z    info • Statements in an if should be enclosed in a block • lib/data/database/app_database.dart:341:34 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4592155Z    info • Statements in an if should be enclosed in a block • lib/data/database/app_database.dart:342:42 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4593227Z    info • Statements in an if should be enclosed in a block • lib/data/database/app_database.dart:357:34 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4594801Z    info • Statements in an if should be enclosed in a block • lib/data/database/app_database.dart:358:42 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4596534Z    info • Statements in an if should be enclosed in a block • lib/data/database/app_database.dart:420:34 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4598284Z    info • Statements in an if should be enclosed in a block • lib/data/database/app_database.dart:421:42 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4599583Z    info • Statements in an if should be enclosed in a block • lib/data/database/app_database.dart:435:34 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4601393Z    info • Statements in an if should be enclosed in a block • lib/data/database/app_database.dart:436:42 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4602861Z    info • Unnecessary 'this.' qualifier • lib/models/deck_model.dart:64:9 • unnecessary_this
2026-02-28T17:40:57.4604143Z    info • Unnecessary 'this.' qualifier • lib/models/deck_model.dart:65:9 • unnecessary_this
2026-02-28T17:40:57.4605349Z    info • Unnecessary 'this.' qualifier • lib/models/deck_model.dart:66:9 • unnecessary_this
2026-02-28T17:40:57.4606414Z    info • Unnecessary 'this.' qualifier • lib/models/deck_model.dart:67:9 • unnecessary_this
2026-02-28T17:40:57.4607579Z    info • Unnecessary 'this.' qualifier • lib/models/deck_model.dart:68:9 • unnecessary_this
2026-02-28T17:40:57.4608827Z    info • Unnecessary use of double quotes • lib/models/player_model.dart:20:17 • prefer_single_quotes
2026-02-28T17:40:57.4610245Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:72:68 • prefer_single_quotes
2026-02-28T17:40:57.4611641Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:72:92 • prefer_single_quotes
2026-02-28T17:40:57.4613055Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:84:35 • prefer_single_quotes
2026-02-28T17:40:57.4615020Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/cards/card_detail_page.dart:85:75 • deprecated_member_use
2026-02-28T17:40:57.4616969Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:118:27 • prefer_single_quotes
2026-02-28T17:40:57.4618502Z    info • Unnecessary use of multiple underscores • lib/pages/cards/card_detail_page.dart:125:39 • unnecessary_underscores
2026-02-28T17:40:57.4620020Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:136:38 • prefer_single_quotes
2026-02-28T17:40:57.4621451Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:222:26 • prefer_single_quotes
2026-02-28T17:40:57.4622878Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:225:23 • prefer_single_quotes
2026-02-28T17:40:57.4624372Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:233:23 • prefer_single_quotes
2026-02-28T17:40:57.4625774Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:250:41 • prefer_single_quotes
2026-02-28T17:40:57.4627205Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:253:37 • prefer_single_quotes
2026-02-28T17:40:57.4628617Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:277:21 • prefer_single_quotes
2026-02-28T17:40:57.4630044Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:282:33 • prefer_single_quotes
2026-02-28T17:40:57.4631569Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:288:31 • prefer_single_quotes
2026-02-28T17:40:57.4632984Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:292:33 • prefer_single_quotes
2026-02-28T17:40:57.4634467Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:298:31 • prefer_single_quotes
2026-02-28T17:40:57.4636320Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/cards/card_detail_page.dart:310:53 • deprecated_member_use
2026-02-28T17:40:57.4637970Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:316:35 • prefer_single_quotes
2026-02-28T17:40:57.4638737Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:324:47 • prefer_single_quotes
2026-02-28T17:40:57.4639506Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:350:76 • prefer_single_quotes
2026-02-28T17:40:57.4640278Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:353:33 • prefer_single_quotes
2026-02-28T17:40:57.4641045Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:373:42 • prefer_single_quotes
2026-02-28T17:40:57.4641813Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:394:27 • prefer_single_quotes
2026-02-28T17:40:57.4642781Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:398:55 • prefer_single_quotes
2026-02-28T17:40:57.4644297Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:402:75 • prefer_single_quotes
2026-02-28T17:40:57.4645732Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:410:31 • prefer_single_quotes
2026-02-28T17:40:57.4647153Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:464:242 • prefer_single_quotes
2026-02-28T17:40:57.4648618Z    info • Unnecessary use of double quotes • lib/pages/cards/card_detail_page.dart:488:35 • prefer_single_quotes
2026-02-28T17:40:57.4650037Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:70:21 • prefer_single_quotes
2026-02-28T17:40:57.4651443Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:103:25 • prefer_single_quotes
2026-02-28T17:40:57.4652852Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:104:25 • prefer_single_quotes
2026-02-28T17:40:57.4654357Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:132:42 • prefer_single_quotes
2026-02-28T17:40:57.4655931Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:201:22 • prefer_single_quotes
2026-02-28T17:40:57.4657355Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:209:28 • prefer_single_quotes
2026-02-28T17:40:57.4659001Z    info • Type could be non-nullable • lib/pages/cards/card_search_page.dart:268:19 • unnecessary_nullable_for_final_variable_declarations
2026-02-28T17:40:57.4660774Z    info • Use 'const' with the constructor to improve performance • lib/pages/cards/card_search_page.dart:278:86 • prefer_const_constructors
2026-02-28T17:40:57.4662344Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:308:30 • prefer_single_quotes
2026-02-28T17:40:57.4664032Z    info • Use 'const' with the constructor to improve performance • lib/pages/cards/card_search_page.dart:361:90 • prefer_const_constructors
2026-02-28T17:40:57.4665624Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:429:33 • prefer_single_quotes
2026-02-28T17:40:57.4667039Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:433:33 • prefer_single_quotes
2026-02-28T17:40:57.4668613Z    info • Don't use 'BuildContext's across async gaps • lib/pages/cards/card_search_page.dart:440:41 • use_build_context_synchronously
2026-02-28T17:40:57.4670421Z    info • Don't use 'BuildContext's across async gaps • lib/pages/cards/card_search_page.dart:442:41 • use_build_context_synchronously
2026-02-28T17:40:57.4671938Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:457:42 • prefer_single_quotes
2026-02-28T17:40:57.4673433Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:479:27 • prefer_single_quotes
2026-02-28T17:40:57.4674846Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:483:55 • prefer_single_quotes
2026-02-28T17:40:57.4676252Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:487:75 • prefer_single_quotes
2026-02-28T17:40:57.4678090Z    info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check • lib/pages/cards/card_search_page.dart:492:44 • use_build_context_synchronously
2026-02-28T17:40:57.4679868Z    info • Unnecessary use of double quotes • lib/pages/cards/card_search_page.dart:495:31 • prefer_single_quotes
2026-02-28T17:40:57.4681687Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/cards/set_list_page.dart:115:31 • deprecated_member_use
2026-02-28T17:40:57.4683883Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/cards/set_list_page.dart:191:27 • deprecated_member_use
2026-02-28T17:40:57.4685686Z    info • Unnecessary use of double quotes • lib/pages/collections/collection_page.dart:95:20 • prefer_single_quotes
2026-02-28T17:40:57.4687260Z    info • Unnecessary use of double quotes • lib/pages/collections/collection_page.dart:100:29 • prefer_single_quotes
2026-02-28T17:40:57.4688807Z    info • Unnecessary use of double quotes • lib/pages/collections/collection_page.dart:109:40 • prefer_single_quotes
2026-02-28T17:40:57.4689796Z    info • Unnecessary use of double quotes • lib/pages/collections/collection_page.dart:117:42 • prefer_single_quotes
2026-02-28T17:40:57.4690610Z    info • Unnecessary use of double quotes • lib/pages/collections/collection_page.dart:139:27 • prefer_single_quotes
2026-02-28T17:40:57.4691416Z    info • Unnecessary use of double quotes • lib/pages/collections/collection_page.dart:142:75 • prefer_single_quotes
2026-02-28T17:40:57.4692219Z    info • Unnecessary use of double quotes • lib/pages/collections/collection_page.dart:143:96 • prefer_single_quotes
2026-02-28T17:40:57.4693056Z    info • Unnecessary use of double quotes • lib/pages/collections/collection_page.dart:197:72 • prefer_single_quotes
2026-02-28T17:40:57.4694533Z    info • Unnecessary use of double quotes • lib/pages/collections/collection_page.dart:198:71 • prefer_single_quotes
2026-02-28T17:40:57.4696252Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/collection_page.dart:214:51 • deprecated_member_use
2026-02-28T17:40:57.4698089Z    info • Unnecessary use of double quotes • lib/pages/collections/collection_page.dart:221:43 • prefer_single_quotes
2026-02-28T17:40:57.4699986Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/collection_page.dart:238:102 • deprecated_member_use
2026-02-28T17:40:57.4701824Z    info • Unnecessary use of double quotes • lib/pages/collections/collection_page.dart:253:47 • prefer_single_quotes
2026-02-28T17:40:57.4703481Z    info • Unnecessary use of double quotes • lib/pages/collections/collection_page.dart:332:27 • prefer_single_quotes
2026-02-28T17:40:57.4704995Z    info • Unnecessary use of double quotes • lib/pages/collections/global_stats_page.dart:93:21 • prefer_single_quotes
2026-02-28T17:40:57.4706510Z    info • Unnecessary use of double quotes • lib/pages/collections/global_stats_page.dart:106:32 • prefer_single_quotes
2026-02-28T17:40:57.4708239Z    info • Unnecessary use of double quotes • lib/pages/collections/global_stats_page.dart:111:32 • prefer_single_quotes
2026-02-28T17:40:57.4709754Z    info • Unnecessary use of double quotes • lib/pages/collections/global_stats_page.dart:116:32 • prefer_single_quotes
2026-02-28T17:40:57.4711385Z    info • Unnecessary use of 'toList' in a spread • lib/pages/collections/global_stats_page.dart:117:64 • unnecessary_to_list_in_spreads
2026-02-28T17:40:57.4714055Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/global_stats_page.dart:128:66 • deprecated_member_use
2026-02-28T17:40:57.4715931Z    info • Unnecessary use of double quotes • lib/pages/collections/global_stats_page.dart:134:16 • prefer_single_quotes
2026-02-28T17:40:57.4717499Z    info • Unnecessary use of double quotes • lib/pages/collections/global_stats_page.dart:137:13 • prefer_single_quotes
2026-02-28T17:40:57.4719016Z    info • Unnecessary use of double quotes • lib/pages/collections/global_stats_page.dart:142:13 • prefer_single_quotes
2026-02-28T17:40:57.4720557Z    info • Unnecessary use of double quotes • lib/pages/collections/global_stats_page.dart:192:59 • prefer_single_quotes
2026-02-28T17:40:57.4722101Z    info • Unnecessary use of double quotes • lib/pages/collections/global_stats_page.dart:230:11 • prefer_single_quotes
2026-02-28T17:40:57.4724139Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/global_stats_page.dart:289:27 • deprecated_member_use
2026-02-28T17:40:57.4726014Z    info • Unnecessary use of double quotes • lib/pages/collections/global_stats_page.dart:307:49 • prefer_single_quotes
2026-02-28T17:40:57.4727733Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:47:25 • prefer_single_quotes
2026-02-28T17:40:57.4729092Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:57:25 • prefer_single_quotes
2026-02-28T17:40:57.4730244Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:67:26 • prefer_single_quotes
2026-02-28T17:40:57.4731457Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:67:47 • prefer_single_quotes
2026-02-28T17:40:57.4732791Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:73:16 • prefer_single_quotes
2026-02-28T17:40:57.4734378Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:75:13 • prefer_single_quotes
2026-02-28T17:40:57.4735845Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:78:22 • prefer_single_quotes
2026-02-28T17:40:57.4737329Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:94:23 • prefer_single_quotes
2026-02-28T17:40:57.4738971Z    info • Don't use 'BuildContext's across async gaps • lib/pages/collections/set_detail_page.dart:105:7 • use_build_context_synchronously
2026-02-28T17:40:57.4740925Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:124:29 • prefer_single_quotes
2026-02-28T17:40:57.4742812Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:137:43 • deprecated_member_use
2026-02-28T17:40:57.4744827Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:141:29 • prefer_single_quotes
2026-02-28T17:40:57.4746749Z    info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check • lib/pages/collections/set_detail_page.dart:147:63 • use_build_context_synchronously
2026-02-28T17:40:57.4748769Z    info • Unnecessary use of multiple underscores • lib/pages/collections/set_detail_page.dart:154:41 • unnecessary_underscores
2026-02-28T17:40:57.4750376Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:165:38 • prefer_single_quotes
2026-02-28T17:40:57.4751937Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:224:26 • prefer_single_quotes
2026-02-28T17:40:57.4753406Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:233:26 • prefer_single_quotes
2026-02-28T17:40:57.4754224Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:268:26 • prefer_single_quotes
2026-02-28T17:40:57.4756074Z    info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre • lib/pages/collections/set_detail_page.dart:313:29 • deprecated_member_use
2026-02-28T17:40:57.4758273Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:315:44 • prefer_single_quotes
2026-02-28T17:40:57.4759731Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:321:60 • prefer_single_quotes
2026-02-28T17:40:57.4761284Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:324:47 • prefer_single_quotes
2026-02-28T17:40:57.4762769Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:327:47 • prefer_single_quotes
2026-02-28T17:40:57.4764442Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:329:62 • prefer_single_quotes
2026-02-28T17:40:57.4765915Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:332:47 • prefer_single_quotes
2026-02-28T17:40:57.4767397Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:342:47 • prefer_single_quotes
2026-02-28T17:40:57.4769443Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:347:46 • deprecated_member_use
2026-02-28T17:40:57.4771269Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:365:35 • prefer_single_quotes
2026-02-28T17:40:57.4772774Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:395:17 • prefer_single_quotes
2026-02-28T17:40:57.4774399Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:405:26 • prefer_single_quotes
2026-02-28T17:40:57.4776289Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:453:27 • deprecated_member_use
2026-02-28T17:40:57.4778511Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:460:39 • deprecated_member_use
2026-02-28T17:40:57.4780352Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:466:29 • prefer_single_quotes
2026-02-28T17:40:57.4782220Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:482:36 • deprecated_member_use
2026-02-28T17:40:57.4784753Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:492:37 • deprecated_member_use
2026-02-28T17:40:57.4786569Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:509:13 • prefer_single_quotes
2026-02-28T17:40:57.4788077Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:514:22 • prefer_single_quotes
2026-02-28T17:40:57.4789573Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:573:25 • prefer_single_quotes
2026-02-28T17:40:57.4791457Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:607:43 • deprecated_member_use
2026-02-28T17:40:57.4793763Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:629:45 • deprecated_member_use
2026-02-28T17:40:57.4795632Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:649:25 • prefer_single_quotes
2026-02-28T17:40:57.4797532Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:707:43 • deprecated_member_use
2026-02-28T17:40:57.4799754Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:709:42 • deprecated_member_use
2026-02-28T17:40:57.4801665Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:761:44 • prefer_single_quotes
2026-02-28T17:40:57.4803311Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:761:53 • prefer_single_quotes
2026-02-28T17:40:57.4804867Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:776:31 • prefer_single_quotes
2026-02-28T17:40:57.4806365Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:805:22 • prefer_single_quotes
2026-02-28T17:40:57.4807860Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:822:38 • prefer_single_quotes
2026-02-28T17:40:57.4809351Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:830:38 • prefer_single_quotes
2026-02-28T17:40:57.4810851Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:847:38 • prefer_single_quotes
2026-02-28T17:40:57.4812585Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:855:38 • prefer_single_quotes
2026-02-28T17:40:57.4814650Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:878:32 • deprecated_member_use
2026-02-28T17:40:57.4816906Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:878:57 • deprecated_member_use
2026-02-28T17:40:57.4819113Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:880:39 • deprecated_member_use
2026-02-28T17:40:57.4821331Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:911:52 • deprecated_member_use
2026-02-28T17:40:57.4823679Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:914:35 • deprecated_member_use
2026-02-28T17:40:57.4825482Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:929:24 • prefer_single_quotes
2026-02-28T17:40:57.4827085Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:940:28 • prefer_single_quotes
2026-02-28T17:40:57.4828542Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:945:28 • prefer_single_quotes
2026-02-28T17:40:57.4829974Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:949:28 • prefer_single_quotes
2026-02-28T17:40:57.4831436Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:960:37 • prefer_single_quotes
2026-02-28T17:40:57.4832889Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:963:37 • prefer_single_quotes
2026-02-28T17:40:57.4834508Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:966:37 • prefer_single_quotes
2026-02-28T17:40:57.4836337Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:979:39 • deprecated_member_use
2026-02-28T17:40:57.4838503Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:1000:55 • deprecated_member_use
2026-02-28T17:40:57.4840679Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:1020:22 • deprecated_member_use
2026-02-28T17:40:57.4842857Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:1022:41 • deprecated_member_use
2026-02-28T17:40:57.4844836Z    info • Unnecessary use of double quotes • lib/pages/collections/set_detail_page.dart:1030:16 • prefer_single_quotes
2026-02-28T17:40:57.4846684Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_detail_page.dart:1032:39 • deprecated_member_use
2026-02-28T17:40:57.4848657Z    info • Parameter 'key' could be a super parameter • lib/pages/collections/set_stats_page.dart:13:9 • use_super_parameters
2026-02-28T17:40:57.4850158Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:143:18 • prefer_single_quotes
2026-02-28T17:40:57.4851621Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:159:32 • prefer_single_quotes
2026-02-28T17:40:57.4853055Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:164:32 • prefer_single_quotes
2026-02-28T17:40:57.4854656Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:167:48 • prefer_single_quotes
2026-02-28T17:40:57.4856279Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:167:58 • prefer_single_quotes
2026-02-28T17:40:57.4857764Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:169:48 • prefer_single_quotes
2026-02-28T17:40:57.4859243Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:169:56 • prefer_single_quotes
2026-02-28T17:40:57.4860698Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:176:34 • prefer_single_quotes
2026-02-28T17:40:57.4862094Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:178:24 • prefer_single_quotes
2026-02-28T17:40:57.4863692Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:188:34 • prefer_single_quotes
2026-02-28T17:40:57.4865189Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:190:24 • prefer_single_quotes
2026-02-28T17:40:57.4867035Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_stats_page.dart:207:29 • deprecated_member_use
2026-02-28T17:40:57.4868811Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:218:46 • prefer_single_quotes
2026-02-28T17:40:57.4870549Z    info • Unnecessary use of multiple underscores • lib/pages/collections/set_stats_page.dart:221:32 • unnecessary_underscores
2026-02-28T17:40:57.4871871Z    info • Unnecessary use of multiple underscores • lib/pages/collections/set_stats_page.dart:221:35 • unnecessary_underscores
2026-02-28T17:40:57.4872799Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:231:19 • prefer_single_quotes
2026-02-28T17:40:57.4873808Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:235:19 • prefer_single_quotes
2026-02-28T17:40:57.4875305Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:240:19 • prefer_single_quotes
2026-02-28T17:40:57.4877015Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:265:11 • prefer_single_quotes
2026-02-28T17:40:57.4878333Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_stats_page.dart:283:22 • deprecated_member_use
2026-02-28T17:40:57.4880329Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_stats_page.dart:285:41 • deprecated_member_use
2026-02-28T17:40:57.4882165Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/set_stats_page.dart:306:27 • deprecated_member_use
2026-02-28T17:40:57.4884012Z    info • Unnecessary use of multiple underscores • lib/pages/collections/set_stats_page.dart:324:90 • unnecessary_underscores
2026-02-28T17:40:57.4885678Z    info • Unnecessary use of multiple underscores • lib/pages/collections/set_stats_page.dart:324:93 • unnecessary_underscores
2026-02-28T17:40:57.4887274Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:327:28 • prefer_single_quotes
2026-02-28T17:40:57.4888797Z    info • Unnecessary use of double quotes • lib/pages/collections/set_stats_page.dart:329:24 • prefer_single_quotes
2026-02-28T17:40:57.4890289Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:42:27 • prefer_single_quotes
2026-02-28T17:40:57.4891771Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:46:55 • prefer_single_quotes
2026-02-28T17:40:57.4893386Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:50:73 • prefer_single_quotes
2026-02-28T17:40:57.4895488Z    info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check • lib/pages/collections/wishlist_tab.dart:55:44 • use_build_context_synchronously
2026-02-28T17:40:57.4897326Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:60:31 • prefer_single_quotes
2026-02-28T17:40:57.4898575Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:72:27 • prefer_single_quotes
2026-02-28T17:40:57.4899374Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:74:80 • prefer_single_quotes
2026-02-28T17:40:57.4900519Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:75:79 • prefer_single_quotes
2026-02-28T17:40:57.4902050Z    info • Don't use 'BuildContext's across async gaps • lib/pages/collections/wishlist_tab.dart:92:28 • use_build_context_synchronously
2026-02-28T17:40:57.4903726Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:115:37 • prefer_single_quotes
2026-02-28T17:40:57.4905224Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:124:35 • prefer_single_quotes
2026-02-28T17:40:57.4906825Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/wishlist_tab.dart:169:33 • deprecated_member_use
2026-02-28T17:40:57.4909090Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/wishlist_tab.dart:171:60 • deprecated_member_use
2026-02-28T17:40:57.4910837Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:180:26 • prefer_single_quotes
2026-02-28T17:40:57.4912278Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:184:35 • prefer_single_quotes
2026-02-28T17:40:57.4913878Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:191:26 • prefer_single_quotes
2026-02-28T17:40:57.4915310Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:206:23 • prefer_single_quotes
2026-02-28T17:40:57.4917138Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/wishlist_tab.dart:247:79 • deprecated_member_use
2026-02-28T17:40:57.4918898Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:249:40 • prefer_single_quotes
2026-02-28T17:40:57.4920367Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:270:115 • prefer_single_quotes
2026-02-28T17:40:57.4921683Z    info • Empty catch block • lib/pages/collections/wishlist_tab.dart:284:34 • empty_catches
2026-02-28T17:40:57.4922857Z    info • Empty catch block • lib/pages/collections/wishlist_tab.dart:291:33 • empty_catches
2026-02-28T17:40:57.4924717Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/wishlist_tab.dart:295:43 • deprecated_member_use
2026-02-28T17:40:57.4926962Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/collections/wishlist_tab.dart:300:81 • deprecated_member_use
2026-02-28T17:40:57.4928740Z    info • Unnecessary use of double quotes • lib/pages/collections/wishlist_tab.dart:306:40 • prefer_single_quotes
2026-02-28T17:40:57.4930203Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:126:79 • prefer_single_quotes
2026-02-28T17:40:57.4931614Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:130:56 • prefer_single_quotes
2026-02-28T17:40:57.4933017Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:135:27 • prefer_single_quotes
2026-02-28T17:40:57.4934568Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:141:141 • prefer_single_quotes
2026-02-28T17:40:57.4935990Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:145:75 • prefer_single_quotes
2026-02-28T17:40:57.4937619Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:146:100 • prefer_single_quotes
2026-02-28T17:40:57.4939049Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:165:79 • prefer_single_quotes
2026-02-28T17:40:57.4940468Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:179:20 • prefer_single_quotes
2026-02-28T17:40:57.4941872Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:183:19 • prefer_single_quotes
2026-02-28T17:40:57.4943357Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:210:33 • prefer_single_quotes
2026-02-28T17:40:57.4945199Z    info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check • lib/pages/decks/deck_detail_page.dart:237:46 • use_build_context_synchronously
2026-02-28T17:40:57.4946748Z    info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check • lib/pages/decks/deck_detail_page.dart:238:46 • use_build_context_synchronously
2026-02-28T17:40:57.4947872Z    info • 'Share' is deprecated and shouldn't be used. Use SharePlus instead • lib/pages/decks/deck_detail_page.dart:241:25 • deprecated_member_use
2026-02-28T17:40:57.4949965Z    info • 'shareXFiles' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead • lib/pages/decks/deck_detail_page.dart:241:31 • deprecated_member_use
2026-02-28T17:40:57.4951674Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:243:27 • prefer_single_quotes
2026-02-28T17:40:57.4953469Z    info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check • lib/pages/decks/deck_detail_page.dart:247:46 • use_build_context_synchronously
2026-02-28T17:40:57.4956413Z    info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check • lib/pages/decks/deck_detail_page.dart:248:46 • use_build_context_synchronously
2026-02-28T17:40:57.4958269Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:249:30 • prefer_single_quotes
2026-02-28T17:40:57.4959815Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:250:104 • prefer_single_quotes
2026-02-28T17:40:57.4961528Z    info • 'Share' is deprecated and shouldn't be used. Use SharePlus instead • lib/pages/decks/deck_detail_page.dart:265:5 • deprecated_member_use
2026-02-28T17:40:57.4963674Z    info • 'share' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead • lib/pages/decks/deck_detail_page.dart:265:11 • deprecated_member_use
2026-02-28T17:40:57.4965436Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:265:32 • prefer_single_quotes
2026-02-28T17:40:57.4966866Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:271:79 • prefer_single_quotes
2026-02-28T17:40:57.4968522Z    info • 'Share' is deprecated and shouldn't be used. Use SharePlus instead • lib/pages/decks/deck_detail_page.dart:275:5 • deprecated_member_use
2026-02-28T17:40:57.4970466Z    info • 'share' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead • lib/pages/decks/deck_detail_page.dart:275:11 • deprecated_member_use
2026-02-28T17:40:57.4972180Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:275:32 • prefer_single_quotes
2026-02-28T17:40:57.4973675Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:281:79 • prefer_single_quotes
2026-02-28T17:40:57.4975306Z    info • 'Share' is deprecated and shouldn't be used. Use SharePlus instead • lib/pages/decks/deck_detail_page.dart:285:5 • deprecated_member_use
2026-02-28T17:40:57.4977261Z    info • 'share' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead • lib/pages/decks/deck_detail_page.dart:285:11 • deprecated_member_use
2026-02-28T17:40:57.4978977Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:285:32 • prefer_single_quotes
2026-02-28T17:40:57.4980576Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:358:18 • prefer_single_quotes
2026-02-28T17:40:57.4982024Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:495:27 • prefer_single_quotes
2026-02-28T17:40:57.4986511Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:509:68 • prefer_single_quotes
2026-02-28T17:40:57.4987338Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:512:68 • prefer_single_quotes
2026-02-28T17:40:57.4988117Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_detail_page.dart:520:19 • prefer_single_quotes
2026-02-28T17:40:57.4989100Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/decks/deck_detail_page.dart:589:63 • deprecated_member_use
2026-02-28T17:40:57.4990067Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_list_page.dart:44:20 • prefer_single_quotes
2026-02-28T17:40:57.4991029Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/decks/deck_list_page.dart:97:46 • deprecated_member_use
2026-02-28T17:40:57.4992099Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_list_page.dart:160:30 • prefer_single_quotes
2026-02-28T17:40:57.4993077Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/decks/deck_list_page.dart:172:45 • deprecated_member_use
2026-02-28T17:40:57.4994209Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_list_page.dart:179:37 • prefer_single_quotes
2026-02-28T17:40:57.4995097Z    info • Statements in an if should be enclosed in a block • lib/pages/decks/deck_list_page.dart:218:67 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4996094Z    info • Statements in an if should be enclosed in a block • lib/pages/decks/deck_list_page.dart:219:70 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.4997153Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/decks/deck_list_page.dart:267:67 • deprecated_member_use
2026-02-28T17:40:57.4998096Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_list_page.dart:284:45 • prefer_single_quotes
2026-02-28T17:40:57.4999061Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/decks/deck_list_page.dart:307:31 • deprecated_member_use
2026-02-28T17:40:57.4999982Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_list_page.dart:343:28 • prefer_single_quotes
2026-02-28T17:40:57.5000731Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_list_page.dart:350:45 • prefer_single_quotes
2026-02-28T17:40:57.5001766Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/decks/deck_list_page.dart:372:71 • deprecated_member_use
2026-02-28T17:40:57.5002693Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_list_page.dart:418:16 • prefer_single_quotes
2026-02-28T17:40:57.5003567Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_list_page.dart:433:29 • prefer_single_quotes
2026-02-28T17:40:57.5004339Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_list_page.dart:435:80 • prefer_single_quotes
2026-02-28T17:40:57.5005100Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_list_page.dart:436:79 • prefer_single_quotes
2026-02-28T17:40:57.5006070Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/decks/deck_list_page.dart:444:29 • deprecated_member_use
2026-02-28T17:40:57.5007210Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/decks/deck_list_page.dart:450:57 • deprecated_member_use
2026-02-28T17:40:57.5008263Z    info • Use 'const' with the constructor to improve performance • lib/pages/decks/deck_list_page.dart:478:32 • prefer_const_constructors
2026-02-28T17:40:57.5009326Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/decks/deck_list_page.dart:504:69 • deprecated_member_use
2026-02-28T17:40:57.5011787Z    info • Unnecessary use of double quotes • lib/pages/decks/deck_list_page.dart:519:25 • prefer_single_quotes
2026-02-28T17:40:57.5013777Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/glossary/glossary_detail_page.dart:48:43 • deprecated_member_use
2026-02-28T17:40:57.5015653Z    info • Unnecessary use of double quotes • lib/pages/glossary/glossary_page.dart:83:11 • prefer_single_quotes
2026-02-28T17:40:57.5017540Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/glossary/glossary_page.dart:131:45 • deprecated_member_use
2026-02-28T17:40:57.5019773Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/glossary/glossary_page.dart:147:49 • deprecated_member_use
2026-02-28T17:40:57.5021707Z    info • Unnecessary use of 'toList' in a spread • lib/pages/glossary/glossary_page.dart:233:16 • unnecessary_to_list_in_spreads
2026-02-28T17:40:57.5023751Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/glossary/glossary_page.dart:243:27 • deprecated_member_use
2026-02-28T17:40:57.5025948Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/glossary/glossary_page.dart:249:41 • deprecated_member_use
2026-02-28T17:40:57.5028137Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/glossary/glossary_page.dart:257:31 • deprecated_member_use
2026-02-28T17:40:57.5030349Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/glossary/glossary_page.dart:268:36 • deprecated_member_use
2026-02-28T17:40:57.5032157Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:25:25 • prefer_single_quotes
2026-02-28T17:40:57.5033801Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:27:15 • prefer_single_quotes
2026-02-28T17:40:57.5035307Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:29:15 • prefer_single_quotes
2026-02-28T17:40:57.5036792Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:34:25 • prefer_single_quotes
2026-02-28T17:40:57.5038249Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:36:15 • prefer_single_quotes
2026-02-28T17:40:57.5039705Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:37:15 • prefer_single_quotes
2026-02-28T17:40:57.5041342Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:38:15 • prefer_single_quotes
2026-02-28T17:40:57.5042810Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:43:25 • prefer_single_quotes
2026-02-28T17:40:57.5044365Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:45:15 • prefer_single_quotes
2026-02-28T17:40:57.5045818Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:46:15 • prefer_single_quotes
2026-02-28T17:40:57.5047271Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:47:15 • prefer_single_quotes
2026-02-28T17:40:57.5048786Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:49:15 • prefer_single_quotes
2026-02-28T17:40:57.5050227Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:54:25 • prefer_single_quotes
2026-02-28T17:40:57.5051692Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:56:15 • prefer_single_quotes
2026-02-28T17:40:57.5053211Z    info • Unnecessary use of double quotes • lib/pages/glossary/turn_guide_page.dart:63:25 • prefer_single_quotes
2026-02-28T17:40:57.5055173Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/glossary/turn_guide_page.dart:91:27 • deprecated_member_use
2026-02-28T17:40:57.5057341Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/glossary/turn_guide_page.dart:96:46 • deprecated_member_use
2026-02-28T17:40:57.5059349Z    info • Use 'const' with the constructor to improve performance • lib/pages/glossary/turn_guide_page.dart:110:18 • prefer_const_constructors
2026-02-28T17:40:57.5061208Z    info • Use 'const' with the constructor to improve performance • lib/pages/glossary/turn_guide_page.dart:120:15 • prefer_const_constructors
2026-02-28T17:40:57.5063048Z    info • Use 'const' with the constructor to improve performance • lib/pages/glossary/turn_guide_page.dart:122:24 • prefer_const_constructors
2026-02-28T17:40:57.5146737Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:15:56 • prefer_single_quotes
2026-02-28T17:40:57.5148509Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:23:32 • prefer_single_quotes
2026-02-28T17:40:57.5149977Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:24:29 • prefer_single_quotes
2026-02-28T17:40:57.5151084Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:25:30 • prefer_single_quotes
2026-02-28T17:40:57.5152641Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:26:23 • prefer_single_quotes
2026-02-28T17:40:57.5154396Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:35:21 • prefer_single_quotes
2026-02-28T17:40:57.5156434Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/life_counter/game_history_detail_page.dart:44:35 • deprecated_member_use
2026-02-28T17:40:57.5158393Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:52:26 • prefer_single_quotes
2026-02-28T17:40:57.5160432Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/life_counter/game_history_detail_page.dart:59:45 • deprecated_member_use
2026-02-28T17:40:57.5161806Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:69:64 • prefer_single_quotes
2026-02-28T17:40:57.5163509Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:70:55 • prefer_single_quotes
2026-02-28T17:40:57.5165442Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:71:56 • prefer_single_quotes
2026-02-28T17:40:57.5167061Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:71:67 • prefer_single_quotes
2026-02-28T17:40:57.5168671Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:80:18 • prefer_single_quotes
2026-02-28T17:40:57.5170698Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/life_counter/game_history_detail_page.dart:87:48 • deprecated_member_use
2026-02-28T17:40:57.5172646Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:107:30 • prefer_single_quotes
2026-02-28T17:40:57.5174348Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:113:30 • prefer_single_quotes
2026-02-28T17:40:57.5175995Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_detail_page.dart:118:28 • prefer_single_quotes
2026-02-28T17:40:57.5177574Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_page.dart:58:20 • prefer_single_quotes
2026-02-28T17:40:57.5179217Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_page.dart:70:56 • prefer_single_quotes
2026-02-28T17:40:57.5180739Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_page.dart:81:21 • prefer_single_quotes
2026-02-28T17:40:57.5182253Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_page.dart:87:24 • prefer_single_quotes
2026-02-28T17:40:57.5183851Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_page.dart:94:83 • prefer_single_quotes
2026-02-28T17:40:57.5185368Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_page.dart:95:99 • prefer_single_quotes
2026-02-28T17:40:57.5186915Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_page.dart:105:32 • prefer_single_quotes
2026-02-28T17:40:57.5188868Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/life_counter/game_history_page.dart:138:31 • deprecated_member_use
2026-02-28T17:40:57.5191181Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/life_counter/game_history_page.dart:142:50 • deprecated_member_use
2026-02-28T17:40:57.5193532Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/life_counter/game_history_page.dart:164:74 • deprecated_member_use
2026-02-28T17:40:57.5195807Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/life_counter/game_history_page.dart:164:105 • deprecated_member_use
2026-02-28T17:40:57.5198076Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/life_counter/game_history_page.dart:166:93 • deprecated_member_use
2026-02-28T17:40:57.5200056Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/life_counter/game_history_page.dart:166:124 • deprecated_member_use
2026-02-28T17:40:57.5201073Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_page.dart:179:26 • prefer_single_quotes
2026-02-28T17:40:57.5202103Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/life_counter/game_history_page.dart:204:87 • deprecated_member_use
2026-02-28T17:40:57.5203261Z    info • Unnecessary use of double quotes • lib/pages/life_counter/game_history_page.dart:210:103 • prefer_single_quotes
2026-02-28T17:40:57.5204565Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:86:56 • prefer_single_quotes
2026-02-28T17:40:57.5206207Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:89:28 • prefer_single_quotes
2026-02-28T17:40:57.5207740Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:89:54 • prefer_single_quotes
2026-02-28T17:40:57.5209912Z    info • 'value' is deprecated and shouldn't be used. Use component accessors like .r or .g, or toARGB32 for an explicit conversion • lib/pages/life_counter/life_counter_page.dart:101:115 • deprecated_member_use
2026-02-28T17:40:57.5211901Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:103:67 • prefer_single_quotes
2026-02-28T17:40:57.5213633Z    info • Statements in a for should be enclosed in a block • lib/pages/life_counter/life_counter_page.dart:174:52 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5214986Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:178:42 • prefer_single_quotes
2026-02-28T17:40:57.5217115Z    info • 'value' is deprecated and shouldn't be used. Use component accessors like .r or .g, or toARGB32 for an explicit conversion • lib/pages/life_counter/life_counter_page.dart:179:92 • deprecated_member_use
2026-02-28T17:40:57.5219327Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:218:37 • prefer_single_quotes
2026-02-28T17:40:57.5221234Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/life_counter/life_counter_page.dart:258:66 • deprecated_member_use
2026-02-28T17:40:57.5223084Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:291:23 • prefer_single_quotes
2026-02-28T17:40:57.5224692Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:316:23 • prefer_single_quotes
2026-02-28T17:40:57.5226754Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:322:35 • prefer_single_quotes
2026-02-28T17:40:57.5228342Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:327:35 • prefer_single_quotes
2026-02-28T17:40:57.5229909Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:332:35 • prefer_single_quotes
2026-02-28T17:40:57.5231489Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:337:35 • prefer_single_quotes
2026-02-28T17:40:57.5233046Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:369:37 • prefer_single_quotes
2026-02-28T17:40:57.5234707Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:369:51 • prefer_single_quotes
2026-02-28T17:40:57.5235856Z    info • 'value' is deprecated and shouldn't be used. Use component accessors like .r or .g, or toARGB32 for an explicit conversion • lib/pages/life_counter/life_counter_page.dart:411:61 • deprecated_member_use
2026-02-28T17:40:57.5237168Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/life_counter/life_counter_page.dart:445:80 • deprecated_member_use
2026-02-28T17:40:57.5238161Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:458:18 • prefer_single_quotes
2026-02-28T17:40:57.5239002Z    info • Unnecessary use of double quotes • lib/pages/life_counter/life_counter_page.dart:463:141 • prefer_single_quotes
2026-02-28T17:40:57.5239825Z    info • Unnecessary use of double quotes • lib/pages/oracle/magic_oracle_page.dart:27:13 • prefer_single_quotes
2026-02-28T17:40:57.5240605Z    info • Unnecessary use of double quotes • lib/pages/oracle/magic_oracle_page.dart:48:16 • prefer_single_quotes
2026-02-28T17:40:57.5241378Z    info • Unnecessary use of double quotes • lib/pages/oracle/magic_oracle_page.dart:92:26 • prefer_single_quotes
2026-02-28T17:40:57.5242342Z    info • Unnecessary use of double quotes • lib/pages/oracle/magic_oracle_page.dart:93:26 • prefer_single_quotes
2026-02-28T17:40:57.5243899Z    info • Unnecessary use of double quotes • lib/pages/oracle/magic_oracle_page.dart:95:26 • prefer_single_quotes
2026-02-28T17:40:57.5245019Z    info • Unnecessary use of double quotes • lib/pages/oracle/magic_oracle_page.dart:96:26 • prefer_single_quotes
2026-02-28T17:40:57.5245813Z    info • Unnecessary use of double quotes • lib/pages/oracle/magic_oracle_page.dart:104:77 • prefer_single_quotes
2026-02-28T17:40:57.5246599Z    info • Unnecessary use of double quotes • lib/pages/oracle/magic_oracle_page.dart:108:34 • prefer_single_quotes
2026-02-28T17:40:57.5247440Z    info • Unnecessary use of double quotes • lib/pages/oracle/magic_oracle_page.dart:111:25 • prefer_single_quotes
2026-02-28T17:40:57.5248463Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/oracle/magic_oracle_page.dart:173:41 • deprecated_member_use
2026-02-28T17:40:57.5249558Z    info • Use 'const' with the constructor to improve performance • lib/pages/oracle/magic_oracle_page.dart:187:33 • prefer_const_constructors
2026-02-28T17:40:57.5250448Z    info • Unnecessary use of double quotes • lib/pages/oracle/magic_oracle_page.dart:188:33 • prefer_single_quotes
2026-02-28T17:40:57.5251550Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/oracle/magic_oracle_page.dart:257:45 • deprecated_member_use
2026-02-28T17:40:57.5252512Z    info • Unnecessary use of double quotes • lib/pages/oracle/magic_oracle_page.dart:269:26 • prefer_single_quotes
2026-02-28T17:40:57.5253463Z    info • Unnecessary use of double quotes • lib/pages/scans/scanner_page.dart:33:26 • prefer_single_quotes
2026-02-28T17:40:57.5254235Z    info • Unnecessary use of double quotes • lib/pages/scans/scanner_page.dart:110:27 • prefer_single_quotes
2026-02-28T17:40:57.5254984Z    info • Unnecessary use of double quotes • lib/pages/scans/scanner_page.dart:145:27 • prefer_single_quotes
2026-02-28T17:40:57.5255751Z    info • Unnecessary use of double quotes • lib/pages/scans/scanner_page.dart:149:11 • prefer_single_quotes
2026-02-28T17:40:57.5256493Z    info • Unnecessary use of double quotes • lib/pages/scans/scanner_page.dart:167:11 • prefer_single_quotes
2026-02-28T17:40:57.5257251Z    info • Unnecessary use of double quotes • lib/pages/scans/scanner_page.dart:213:22 • prefer_single_quotes
2026-02-28T17:40:57.5257998Z    info • Unnecessary use of double quotes • lib/pages/scans/scanner_page.dart:238:17 • prefer_single_quotes
2026-02-28T17:40:57.5258734Z    info • Unnecessary use of double quotes • lib/pages/scans/scanner_page.dart:251:35 • prefer_single_quotes
2026-02-28T17:40:57.5259472Z    info • Unnecessary use of double quotes • lib/pages/scans/scanner_page.dart:273:21 • prefer_single_quotes
2026-02-28T17:40:57.5260311Z    info • Don't use 'BuildContext's across async gaps • lib/pages/scans/scanner_page.dart:317:28 • use_build_context_synchronously
2026-02-28T17:40:57.5261135Z    info • Unnecessary use of double quotes • lib/pages/scans/scanner_page.dart:338:11 • prefer_single_quotes
2026-02-28T17:40:57.5261985Z    info • Use 'const' with the constructor to improve performance • lib/pages/scans/scanner_page.dart:418:35 • prefer_const_constructors
2026-02-28T17:40:57.5262831Z    info • Unnecessary use of double quotes • lib/pages/scans/scanner_page.dart:419:35 • prefer_single_quotes
2026-02-28T17:40:57.5263739Z    info • Use 'const' with the constructor to improve performance • lib/pages/scans/scanner_page.dart:420:36 • prefer_const_constructors
2026-02-28T17:40:57.5264568Z    info • Unnecessary use of double quotes • lib/pages/scans/scanner_page.dart:440:31 • prefer_single_quotes
2026-02-28T17:40:57.5265537Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/scans/scanner_page.dart:491:32 • deprecated_member_use
2026-02-28T17:40:57.5266844Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/scans/scanner_page.dart:516:30 • deprecated_member_use
2026-02-28T17:40:57.5268909Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/scans/scanner_page.dart:516:71 • deprecated_member_use
2026-02-28T17:40:57.5270312Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/settings/dev_tools_page.dart:91:27 • deprecated_member_use
2026-02-28T17:40:57.5271455Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/settings/dev_tools_page.dart:106:31 • deprecated_member_use
2026-02-28T17:40:57.5272459Z    info • Unnecessary use of double quotes • lib/pages/settings/profile_management_page.dart:45:21 • prefer_single_quotes
2026-02-28T17:40:57.5273385Z    info • Unnecessary use of double quotes • lib/pages/settings/profile_management_page.dart:51:36 • prefer_single_quotes
2026-02-28T17:40:57.5274501Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/settings/profile_management_page.dart:67:27 • deprecated_member_use
2026-02-28T17:40:57.5275534Z    info • Unnecessary use of double quotes • lib/pages/settings/profile_management_page.dart:75:15 • prefer_single_quotes
2026-02-28T17:40:57.5276463Z    info • Unnecessary use of double quotes • lib/pages/settings/profile_management_page.dart:76:40 • prefer_single_quotes
2026-02-28T17:40:57.5277306Z    info • Unnecessary use of double quotes • lib/pages/settings/profile_management_page.dart:121:42 • prefer_single_quotes
2026-02-28T17:40:57.5278161Z    info • Unnecessary use of double quotes • lib/pages/settings/profile_management_page.dart:121:61 • prefer_single_quotes
2026-02-28T17:40:57.5279003Z    info • Unnecessary use of double quotes • lib/pages/settings/profile_management_page.dart:128:64 • prefer_single_quotes
2026-02-28T17:40:57.5279871Z    info • Unnecessary use of double quotes • lib/pages/settings/profile_management_page.dart:133:26 • prefer_single_quotes
2026-02-28T17:40:57.5280730Z    info • Unnecessary use of double quotes • lib/pages/settings/profile_management_page.dart:143:26 • prefer_single_quotes
2026-02-28T17:40:57.5281809Z    info • Don't use 'BuildContext's across async gaps • lib/pages/settings/profile_management_page.dart:173:33 • use_build_context_synchronously
2026-02-28T17:40:57.5282729Z    info • Unnecessary use of double quotes • lib/pages/settings/profile_management_page.dart:176:35 • prefer_single_quotes
2026-02-28T17:40:57.5283633Z    info • Unnecessary use of double quotes • lib/pages/settings/profile_management_page.dart:178:83 • prefer_single_quotes
2026-02-28T17:40:57.5284789Z    info • 'value' is deprecated and shouldn't be used. Use component accessors like .r or .g, or toARGB32 for an explicit conversion • lib/pages/settings/profile_management_page.dart:185:47 • deprecated_member_use
2026-02-28T17:40:57.5286000Z    info • Don't use 'BuildContext's across async gaps • lib/pages/settings/profile_management_page.dart:194:33 • use_build_context_synchronously
2026-02-28T17:40:57.5286910Z    info • Unnecessary use of double quotes • lib/pages/settings/profile_management_page.dart:198:33 • prefer_single_quotes
2026-02-28T17:40:57.5287970Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/settings/profile_management_page.dart:210:31 • deprecated_member_use
2026-02-28T17:40:57.5289022Z    info • Unnecessary use of double quotes • lib/pages/settings/profile_management_page.dart:213:30 • prefer_single_quotes
2026-02-28T17:40:57.5289838Z    info • Unnecessary use of double quotes • lib/pages/settings/settings_page.dart:24:86 • prefer_single_quotes
2026-02-28T17:40:57.5290614Z    info • Unnecessary use of double quotes • lib/pages/settings/settings_page.dart:44:86 • prefer_single_quotes
2026-02-28T17:40:57.5291390Z    info • Unnecessary use of double quotes • lib/pages/settings/settings_page.dart:63:32 • prefer_single_quotes
2026-02-28T17:40:57.5292254Z    info • Unnecessary use of double quotes • lib/pages/settings/settings_page.dart:70:39 • prefer_single_quotes
2026-02-28T17:40:57.5293026Z    info • Unnecessary use of double quotes • lib/pages/settings/settings_page.dart:71:42 • prefer_single_quotes
2026-02-28T17:40:57.5293948Z    info • Unnecessary use of double quotes • lib/pages/settings/settings_page.dart:77:39 • prefer_single_quotes
2026-02-28T17:40:57.5294722Z    info • Unnecessary use of double quotes • lib/pages/settings/settings_page.dart:78:42 • prefer_single_quotes
2026-02-28T17:40:57.5295492Z    info • Unnecessary use of double quotes • lib/pages/settings/settings_page.dart:85:32 • prefer_single_quotes
2026-02-28T17:40:57.5296376Z    info • Use 'const' with the constructor to improve performance • lib/pages/settings/settings_page.dart:88:22 • prefer_const_constructors
2026-02-28T17:40:57.5297237Z    info • Unnecessary use of double quotes • lib/pages/settings/settings_page.dart:90:35 • prefer_single_quotes
2026-02-28T17:40:57.5298018Z    info • Unnecessary use of double quotes • lib/pages/settings/settings_page.dart:91:38 • prefer_single_quotes
2026-02-28T17:40:57.5298804Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:64:79 • prefer_single_quotes
2026-02-28T17:40:57.5299674Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:98:21 • prefer_single_quotes
2026-02-28T17:40:57.5300482Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:113:68 • prefer_single_quotes
2026-02-28T17:40:57.5301280Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:113:83 • prefer_single_quotes
2026-02-28T17:40:57.5302078Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:115:66 • prefer_single_quotes
2026-02-28T17:40:57.5302881Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:115:84 • prefer_single_quotes
2026-02-28T17:40:57.5303800Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:121:64 • prefer_single_quotes
2026-02-28T17:40:57.5304601Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:121:76 • prefer_single_quotes
2026-02-28T17:40:57.5305425Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:123:66 • prefer_single_quotes
2026-02-28T17:40:57.5306224Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:123:83 • prefer_single_quotes
2026-02-28T17:40:57.5307021Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:135:29 • prefer_single_quotes
2026-02-28T17:40:57.5308041Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/tools/hypergeometric_page.dart:144:41 • deprecated_member_use
2026-02-28T17:40:57.5309087Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:150:28 • prefer_single_quotes
2026-02-28T17:40:57.5309890Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:153:39 • prefer_single_quotes
2026-02-28T17:40:57.5310704Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:154:39 • prefer_single_quotes
2026-02-28T17:40:57.5311509Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:155:39 • prefer_single_quotes
2026-02-28T17:40:57.5312309Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:173:11 • prefer_single_quotes
2026-02-28T17:40:57.5313389Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/tools/hypergeometric_page.dart:193:54 • deprecated_member_use
2026-02-28T17:40:57.5314380Z    info • Unnecessary use of double quotes • lib/pages/tools/hypergeometric_page.dart:222:13 • prefer_single_quotes
2026-02-28T17:40:57.5315218Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:13:29 • prefer_single_quotes
2026-02-28T17:40:57.5316053Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:132:79 • prefer_single_quotes
2026-02-28T17:40:57.5316952Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:140:68 • prefer_single_quotes
2026-02-28T17:40:57.5317781Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:172:41 • prefer_single_quotes
2026-02-28T17:40:57.5318601Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:172:57 • prefer_single_quotes
2026-02-28T17:40:57.5319410Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:246:21 • prefer_single_quotes
2026-02-28T17:40:57.5320237Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:249:130 • prefer_single_quotes
2026-02-28T17:40:57.5321091Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:249:159 • prefer_single_quotes
2026-02-28T17:40:57.5321927Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:261:16 • prefer_single_quotes
2026-02-28T17:40:57.5322761Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:265:153 • prefer_single_quotes
2026-02-28T17:40:57.5323861Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/tournaments/tournament_page.dart:265:211 • deprecated_member_use
2026-02-28T17:40:57.5325073Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/tournaments/tournament_page.dart:271:122 • deprecated_member_use
2026-02-28T17:40:57.5326071Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:271:225 • prefer_single_quotes
2026-02-28T17:40:57.5327029Z    info • Statements in a for should be enclosed in a block • lib/pages/tournaments/tournament_page.dart:280:28 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5328159Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/tournaments/tournament_page.dart:292:159 • deprecated_member_use
2026-02-28T17:40:57.5329179Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:293:62 • prefer_single_quotes
2026-02-28T17:40:57.5329992Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:293:165 • prefer_single_quotes
2026-02-28T17:40:57.5330811Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:295:62 • prefer_single_quotes
2026-02-28T17:40:57.5331622Z    info • Unnecessary use of double quotes • lib/pages/tournaments/tournament_page.dart:295:165 • prefer_single_quotes
2026-02-28T17:40:57.5333049Z    info • The import of 'package:flutter/services.dart' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/material.dart' • lib/pages/wishlists/wishlist_detail_page.dart:4:8 • unnecessary_import
2026-02-28T17:40:57.5334449Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:101:21 • prefer_single_quotes
2026-02-28T17:40:57.5335293Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:102:29 • prefer_single_quotes
2026-02-28T17:40:57.5336134Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:104:82 • prefer_single_quotes
2026-02-28T17:40:57.5336979Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:105:81 • prefer_single_quotes
2026-02-28T17:40:57.5337817Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:125:16 • prefer_single_quotes
2026-02-28T17:40:57.5338596Z    info • Empty catch block • lib/pages/wishlists/wishlist_detail_page.dart:126:18 • empty_catches
2026-02-28T17:40:57.5339392Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:128:18 • prefer_single_quotes
2026-02-28T17:40:57.5340337Z    info • 'Share' is deprecated and shouldn't be used. Use SharePlus instead • lib/pages/wishlists/wishlist_detail_page.dart:131:5 • deprecated_member_use
2026-02-28T17:40:57.5341844Z    info • 'share' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead • lib/pages/wishlists/wishlist_detail_page.dart:131:11 • deprecated_member_use
2026-02-28T17:40:57.5342867Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:131:41 • prefer_single_quotes
2026-02-28T17:40:57.5343775Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:145:20 • prefer_single_quotes
2026-02-28T17:40:57.5344540Z    info • Empty catch block • lib/pages/wishlists/wishlist_detail_page.dart:161:32 • empty_catches
2026-02-28T17:40:57.5345409Z    info • Don't use 'BuildContext's across async gaps • lib/pages/wishlists/wishlist_detail_page.dart:166:39 • use_build_context_synchronously
2026-02-28T17:40:57.5346383Z    info • Don't use 'BuildContext's across async gaps • lib/pages/wishlists/wishlist_detail_page.dart:167:46 • use_build_context_synchronously
2026-02-28T17:40:57.5347385Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:167:97 • prefer_single_quotes
2026-02-28T17:40:57.5348294Z    info • Don't use 'BuildContext's across async gaps • lib/pages/wishlists/wishlist_detail_page.dart:183:34 • use_build_context_synchronously
2026-02-28T17:40:57.5349190Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:186:35 • prefer_single_quotes
2026-02-28T17:40:57.5350040Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:211:144 • prefer_single_quotes
2026-02-28T17:40:57.5350885Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:212:138 • prefer_single_quotes
2026-02-28T17:40:57.5351720Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:213:143 • prefer_single_quotes
2026-02-28T17:40:57.5352664Z    info • Use 'const' with the constructor to improve performance • lib/pages/wishlists/wishlist_detail_page.dart:229:34 • prefer_const_constructors
2026-02-28T17:40:57.5353991Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/pages/wishlists/wishlist_detail_page.dart:277:27 • deprecated_member_use
2026-02-28T17:40:57.5355009Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:280:16 • prefer_single_quotes
2026-02-28T17:40:57.5355835Z    info • Unnecessary use of double quotes • lib/pages/wishlists/wishlist_detail_page.dart:283:13 • prefer_single_quotes
2026-02-28T17:40:57.5356824Z    info • Use 'const' with the constructor to improve performance • lib/router/app_router.dart:141:38 • prefer_const_constructors
2026-02-28T17:40:57.5357842Z    info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check • lib/router/app_router.dart:546:46 • use_build_context_synchronously
2026-02-28T17:40:57.5359277Z    info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check • lib/router/app_router.dart:556:46 • use_build_context_synchronously
2026-02-28T17:40:57.5361121Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:54:28 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5362956Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:58:32 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5365000Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:98:32 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5366849Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:102:32 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5368817Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:122:28 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5370930Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:133:35 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5372876Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:136:34 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5374915Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:139:35 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5376413Z    info • Unnecessary use of double quotes • lib/services/backup_service.dart:188:11 • prefer_single_quotes
2026-02-28T17:40:57.5377760Z    info • Unnecessary use of double quotes • lib/services/backup_service.dart:189:23 • prefer_single_quotes
2026-02-28T17:40:57.5379329Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:196:14 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5381178Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:197:14 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5382967Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:200:36 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5385131Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:202:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5386960Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:206:40 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5388824Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:208:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5390689Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:212:39 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5392600Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:214:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5394626Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:221:18 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5396366Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:236:18 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5398134Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:248:22 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5400194Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:267:18 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5402019Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:275:20 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5403334Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:288:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5404339Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:291:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5405323Z warning • The '!' will have no effect because the receiver can't be null • lib/services/backup_service.dart:294:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5406336Z    info • 'Share' is deprecated and shouldn't be used. Use SharePlus instead • lib/services/backup_service.dart:325:11 • deprecated_member_use
2026-02-28T17:40:57.5407408Z    info • 'shareXFiles' is deprecated and shouldn't be used. Use SharePlus.instance.share() instead • lib/services/backup_service.dart:325:17 • deprecated_member_use
2026-02-28T17:40:57.5408349Z    info • Unnecessary use of double quotes • lib/services/backup_service.dart:343:11 • prefer_single_quotes
2026-02-28T17:40:57.5409393Z warning • The '!' will have no effect because the receiver can't be null • lib/services/collection_service.dart:23:30 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5410402Z warning • The '!' will have no effect because the receiver can't be null • lib/services/collection_service.dart:59:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5411419Z warning • The '!' will have no effect because the receiver can't be null • lib/services/collection_service.dart:140:25 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5412315Z    info • Unnecessary use of double quotes • lib/services/collection_service.dart:153:14 • prefer_single_quotes
2026-02-28T17:40:57.5413189Z    info • Unnecessary use of double quotes • lib/services/collection_service.dart:169:24 • prefer_single_quotes
2026-02-28T17:40:57.5414180Z warning • The '!' will have no effect because the receiver can't be null • lib/services/collection_service.dart:172:18 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5415200Z warning • The '!' will have no effect because the receiver can't be null • lib/services/collection_service.dart:195:19 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5416523Z warning • The '!' will have no effect because the receiver can't be null • lib/services/collection_service.dart:228:18 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5418514Z warning • The '!' will have no effect because the receiver can't be null • lib/services/collection_service.dart:236:19 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5420294Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:31:33 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5421964Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:34:32 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5423643Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:95:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5425215Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:106:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5426770Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:127:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5428358Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:135:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5429947Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:143:20 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5431931Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:175:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5433937Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:185:33 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5435864Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:186:30 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5437787Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:253:18 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5439716Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:258:18 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5441670Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:263:33 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5443591Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:264:30 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5445148Z    info • Statements in an if should be enclosed in a block • lib/services/deck_service.dart:272:20 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5446902Z    info • Statements in an if should be enclosed in a block • lib/services/deck_service.dart:273:10 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5448711Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:281:33 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5450434Z    info • Statements in an if should be enclosed in a block • lib/services/deck_service.dart:286:22 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5452130Z    info • Statements in an if should be enclosed in a block • lib/services/deck_service.dart:287:12 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5454115Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:291:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5456067Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:296:37 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5457948Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:297:30 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5459844Z    info • Statements in an if should be enclosed in a block • lib/services/deck_service.dart:305:20 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5461735Z    info • Statements in an if should be enclosed in a block • lib/services/deck_service.dart:306:10 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5463774Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:318:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5465751Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:319:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5467658Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:324:37 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5469572Z warning • The '!' will have no effect because the receiver can't be null • lib/services/deck_service.dart:325:30 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5471112Z    info • Unnecessary use of double quotes • lib/services/edhrec_service.dart:29:35 • prefer_single_quotes
2026-02-28T17:40:57.5472505Z    info • Unnecessary use of double quotes • lib/services/edhrec_service.dart:29:54 • prefer_single_quotes
2026-02-28T17:40:57.5473768Z    info • Unnecessary use of double quotes • lib/services/edhrec_service.dart:32:42 • prefer_single_quotes
2026-02-28T17:40:57.5474671Z    info • Unnecessary use of double quotes • lib/services/edhrec_service.dart:32:51 • prefer_single_quotes
2026-02-28T17:40:57.5475605Z warning • The '!' will have no effect because the receiver can't be null • lib/services/game_history_service.dart:17:30 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5477496Z warning • The '!' will have no effect because the receiver can't be null • lib/services/game_history_service.dart:43:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5478532Z warning • The '!' will have no effect because the receiver can't be null • lib/services/game_history_service.dart:64:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5479437Z    info • Unnecessary use of double quotes • lib/services/google_drive_service.dart:15:41 • prefer_single_quotes
2026-02-28T17:40:57.5480241Z    info • Unnecessary use of double quotes • lib/services/google_drive_service.dart:29:11 • prefer_single_quotes
2026-02-28T17:40:57.5481037Z    info • Unnecessary use of double quotes • lib/services/google_drive_service.dart:55:16 • prefer_single_quotes
2026-02-28T17:40:57.5481818Z    info • Unnecessary use of double quotes • lib/services/google_drive_service.dart:111:11 • prefer_single_quotes
2026-02-28T17:40:57.5482596Z    info • Unnecessary use of double quotes • lib/services/google_drive_service.dart:120:11 • prefer_single_quotes
2026-02-28T17:40:57.5483618Z    info • Unnecessary use of double quotes • lib/services/local_card_service.dart:97:18 • prefer_single_quotes
2026-02-28T17:40:57.5484389Z    info • Unnecessary use of double quotes • lib/services/local_card_service.dart:99:18 • prefer_single_quotes
2026-02-28T17:40:57.5485148Z    info • Unnecessary use of double quotes • lib/services/oracle_service.dart:17:11 • prefer_single_quotes
2026-02-28T17:40:57.5486026Z warning • The '!' will have no effect because the receiver can't be null • lib/services/profile_service.dart:17:35 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5487023Z warning • The '!' will have no effect because the receiver can't be null • lib/services/profile_service.dart:40:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5487996Z warning • The '!' will have no effect because the receiver can't be null • lib/services/profile_service.dart:66:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5488994Z warning • The '!' will have no effect because the receiver can't be null • lib/services/scan_history_service.dart:19:30 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5490005Z warning • The '!' will have no effect because the receiver can't be null • lib/services/scan_history_service.dart:50:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5490997Z warning • The '!' will have no effect because the receiver can't be null • lib/services/scan_history_service.dart:70:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5491983Z warning • The '!' will have no effect because the receiver can't be null • lib/services/wishlist_service.dart:24:37 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5492982Z warning • The '!' will have no effect because the receiver can't be null • lib/services/wishlist_service.dart:28:18 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5494097Z warning • The '!' will have no effect because the receiver can't be null • lib/services/wishlist_service.dart:42:32 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5494959Z    info • Unnecessary use of double quotes • lib/services/wishlist_service.dart:70:15 • prefer_single_quotes
2026-02-28T17:40:57.5495719Z    info • Unnecessary use of double quotes • lib/services/wishlist_service.dart:90:17 • prefer_single_quotes
2026-02-28T17:40:57.5496477Z    info • Unnecessary use of double quotes • lib/services/wishlist_service.dart:99:11 • prefer_single_quotes
2026-02-28T17:40:57.5497233Z    info • Unnecessary use of double quotes • lib/services/wishlist_service.dart:101:11 • prefer_single_quotes
2026-02-28T17:40:57.5498219Z warning • The '!' will have no effect because the receiver can't be null • lib/services/wishlist_service.dart:116:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5499215Z warning • The '!' will have no effect because the receiver can't be null • lib/services/wishlist_service.dart:135:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5500208Z warning • The '!' will have no effect because the receiver can't be null • lib/services/wishlist_service.dart:145:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5501213Z warning • The '!' will have no effect because the receiver can't be null • lib/services/wishlist_service.dart:160:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5502201Z warning • The '!' will have no effect because the receiver can't be null • lib/services/wishlist_service.dart:184:36 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5503305Z warning • The '!' will have no effect because the receiver can't be null • lib/services/wishlist_service.dart:188:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5504296Z warning • The '!' will have no effect because the receiver can't be null • lib/services/wishlist_service.dart:224:16 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5505279Z    info • Statements in an if should be enclosed in a block • lib/utils/card_list_upsert_mixin.dart:53:34 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5506353Z    info • Statements in an if should be enclosed in a block • lib/utils/card_list_upsert_mixin.dart:54:42 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5507272Z    info • Unnecessary use of double quotes • lib/widgets/cards/versions_selector_sheet.dart:44:25 • prefer_single_quotes
2026-02-28T17:40:57.5508111Z    info • Unnecessary use of double quotes • lib/widgets/cards/versions_selector_sheet.dart:68:27 • prefer_single_quotes
2026-02-28T17:40:57.5508950Z    info • Unnecessary use of double quotes • lib/widgets/cards/versions_selector_sheet.dart:91:22 • prefer_single_quotes
2026-02-28T17:40:57.5509850Z    info • Unnecessary use of multiple underscores • lib/widgets/cards/versions_selector_sheet.dart:138:58 • unnecessary_underscores
2026-02-28T17:40:57.5510772Z    info • Unnecessary use of multiple underscores • lib/widgets/cards/versions_selector_sheet.dart:138:61 • unnecessary_underscores
2026-02-28T17:40:57.5511646Z    info • Unnecessary use of double quotes • lib/widgets/cards/versions_selector_sheet.dart:154:43 • prefer_single_quotes
2026-02-28T17:40:57.5512498Z    info • Unnecessary use of double quotes • lib/widgets/cards/versions_selector_sheet.dart:163:103 • prefer_single_quotes
2026-02-28T17:40:57.5513549Z    info • Don't use 'BuildContext's across async gaps • lib/widgets/collection/collection_list_tab.dart:81:28 • use_build_context_synchronously
2026-02-28T17:40:57.5514471Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:88:20 • prefer_single_quotes
2026-02-28T17:40:57.5515312Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:93:24 • prefer_single_quotes
2026-02-28T17:40:57.5516170Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:98:17 • prefer_single_quotes
2026-02-28T17:40:57.5517007Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:102:46 • prefer_single_quotes
2026-02-28T17:40:57.5517861Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:102:64 • prefer_single_quotes
2026-02-28T17:40:57.5518720Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:254:27 • prefer_single_quotes
2026-02-28T17:40:57.5519798Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_list_tab.dart:265:60 • deprecated_member_use
2026-02-28T17:40:57.5520841Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:270:32 • prefer_single_quotes
2026-02-28T17:40:57.5521792Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:273:164 • prefer_single_quotes
2026-02-28T17:40:57.5522647Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:283:32 • prefer_single_quotes
2026-02-28T17:40:57.5523785Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:295:87 • prefer_single_quotes
2026-02-28T17:40:57.5524722Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:301:37 • prefer_single_quotes
2026-02-28T17:40:57.5525568Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:325:43 • prefer_single_quotes
2026-02-28T17:40:57.5526424Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:325:61 • prefer_single_quotes
2026-02-28T17:40:57.5527484Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_list_tab.dart:334:33 • deprecated_member_use
2026-02-28T17:40:57.5528512Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:352:25 • prefer_single_quotes
2026-02-28T17:40:57.5529362Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:354:25 • prefer_single_quotes
2026-02-28T17:40:57.5530152Z    info • Empty catch block • lib/widgets/collection/collection_list_tab.dart:400:100 • empty_catches
2026-02-28T17:40:57.5531145Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_list_tab.dart:416:40 • deprecated_member_use
2026-02-28T17:40:57.5532382Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_list_tab.dart:416:72 • deprecated_member_use
2026-02-28T17:40:57.5533686Z    info • Statements in an if should be enclosed in a block • lib/widgets/collection/collection_list_tab.dart:426:39 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5534788Z    info • Statements in an if should be enclosed in a block • lib/widgets/collection/collection_list_tab.dart:427:82 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5535810Z    info • Unnecessary use of multiple underscores • lib/widgets/collection/collection_list_tab.dart:438:122 • unnecessary_underscores
2026-02-28T17:40:57.5536762Z    info • Unnecessary use of multiple underscores • lib/widgets/collection/collection_list_tab.dart:438:125 • unnecessary_underscores
2026-02-28T17:40:57.5537663Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:451:20 • prefer_single_quotes
2026-02-28T17:40:57.5538507Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:470:22 • prefer_single_quotes
2026-02-28T17:40:57.5539564Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_list_tab.dart:481:72 • deprecated_member_use
2026-02-28T17:40:57.5540890Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_list_tab.dart:481:174 • deprecated_member_use
2026-02-28T17:40:57.5541858Z    info • Empty catch block • lib/widgets/collection/collection_list_tab.dart:501:100 • empty_catches
2026-02-28T17:40:57.5542760Z    info • Statements in an if should be enclosed in a block • lib/widgets/collection/collection_list_tab.dart:515:37 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5543898Z    info • Statements in an if should be enclosed in a block • lib/widgets/collection/collection_list_tab.dart:516:80 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5545070Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_list_tab.dart:539:98 • deprecated_member_use
2026-02-28T17:40:57.5546313Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_list_tab.dart:543:45 • deprecated_member_use
2026-02-28T17:40:57.5547554Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_list_tab.dart:548:162 • deprecated_member_use
2026-02-28T17:40:57.5548649Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:560:26 • prefer_single_quotes
2026-02-28T17:40:57.5549504Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:589:27 • prefer_single_quotes
2026-02-28T17:40:57.5550352Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:602:96 • prefer_single_quotes
2026-02-28T17:40:57.5551197Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:603:96 • prefer_single_quotes
2026-02-28T17:40:57.5552052Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:604:97 • prefer_single_quotes
2026-02-28T17:40:57.5552904Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:606:123 • prefer_single_quotes
2026-02-28T17:40:57.5553832Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:606:140 • prefer_single_quotes
2026-02-28T17:40:57.5554896Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_list_tab.dart:624:43 • deprecated_member_use
2026-02-28T17:40:57.5556123Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_list_tab.dart:624:74 • deprecated_member_use
2026-02-28T17:40:57.5557357Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_list_tab.dart:628:58 • deprecated_member_use
2026-02-28T17:40:57.5558598Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_list_tab.dart:657:102 • deprecated_member_use
2026-02-28T17:40:57.5559626Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_list_tab.dart:670:29 • prefer_single_quotes
2026-02-28T17:40:57.5560679Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_sets_tab.dart:206:31 • deprecated_member_use
2026-02-28T17:40:57.5561892Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_sets_tab.dart:217:45 • deprecated_member_use
2026-02-28T17:40:57.5562919Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_sets_tab.dart:224:37 • prefer_single_quotes
2026-02-28T17:40:57.5564104Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_sets_tab.dart:253:23 • prefer_single_quotes
2026-02-28T17:40:57.5565156Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_sets_tab.dart:291:39 • deprecated_member_use
2026-02-28T17:40:57.5566197Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_sets_tab.dart:309:48 • prefer_single_quotes
2026-02-28T17:40:57.5567044Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_sets_tab.dart:310:54 • prefer_single_quotes
2026-02-28T17:40:57.5567896Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_sets_tab.dart:311:48 • prefer_single_quotes
2026-02-28T17:40:57.5568745Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_sets_tab.dart:312:48 • prefer_single_quotes
2026-02-28T17:40:57.5569600Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_sets_tab.dart:313:48 • prefer_single_quotes
2026-02-28T17:40:57.5570654Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_sets_tab.dart:342:55 • deprecated_member_use
2026-02-28T17:40:57.5571744Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_sets_tab.dart:345:16 • prefer_single_quotes
2026-02-28T17:40:57.5572708Z    info • Statements in an if should be enclosed in a block • lib/widgets/collection/collection_sets_tab.dart:349:31 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5573933Z    info • Statements in an if should be enclosed in a block • lib/widgets/collection/collection_sets_tab.dart:350:16 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5575091Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/collection/collection_sets_tab.dart:369:67 • deprecated_member_use
2026-02-28T17:40:57.5576120Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_sets_tab.dart:374:16 • prefer_single_quotes
2026-02-28T17:40:57.5576983Z    info • Unnecessary use of double quotes • lib/widgets/collection/collection_sets_tab.dart:425:12 • prefer_single_quotes
2026-02-28T17:40:57.5577821Z    info • Unnecessary use of double quotes • lib/widgets/collection/quick_add_view.dart:64:87 • prefer_single_quotes
2026-02-28T17:40:57.5578677Z    info • Unnecessary use of multiple underscores • lib/widgets/collection/quick_add_view.dart:79:90 • unnecessary_underscores
2026-02-28T17:40:57.5579576Z    info • Unnecessary use of multiple underscores • lib/widgets/collection/quick_add_view.dart:79:93 • unnecessary_underscores
2026-02-28T17:40:57.5580417Z    info • Unnecessary use of double quotes • lib/widgets/collection/quick_add_view.dart:89:22 • prefer_single_quotes
2026-02-28T17:40:57.5581220Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:71:18 • prefer_single_quotes
2026-02-28T17:40:57.5582033Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:74:77 • prefer_single_quotes
2026-02-28T17:40:57.5582825Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:75:16 • prefer_single_quotes
2026-02-28T17:40:57.5583893Z    info • Use 'const' with the constructor to improve performance • lib/widgets/decks/deck_card_list_tab.dart:89:16 • prefer_const_constructors
2026-02-28T17:40:57.5584884Z    info • Use 'const' with the constructor to improve performance • lib/widgets/decks/deck_card_list_tab.dart:91:25 • prefer_const_constructors
2026-02-28T17:40:57.5585868Z    info • Use 'const' with the constructor to improve performance • lib/widgets/decks/deck_card_list_tab.dart:91:142 • prefer_const_constructors
2026-02-28T17:40:57.5586768Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:109:20 • prefer_single_quotes
2026-02-28T17:40:57.5587667Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:114:28 • prefer_single_quotes
2026-02-28T17:40:57.5588461Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:121:28 • prefer_single_quotes
2026-02-28T17:40:57.5589204Z    info • Empty catch block • lib/widgets/decks/deck_card_list_tab.dart:198:104 • empty_catches
2026-02-28T17:40:57.5590110Z warning • The '!' will have no effect because the receiver can't be null • lib/widgets/decks/deck_card_list_tab.dart:207:114 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5591161Z warning • The '!' will have no effect because the receiver can't be null • lib/widgets/decks/deck_card_list_tab.dart:213:114 • unnecessary_non_null_assertion
2026-02-28T17:40:57.5592071Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:253:33 • prefer_single_quotes
2026-02-28T17:40:57.5592872Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:285:49 • prefer_single_quotes
2026-02-28T17:40:57.5593731Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:285:69 • prefer_single_quotes
2026-02-28T17:40:57.5594915Z    info • 'activeColor' is deprecated and shouldn't be used. Use activeThumbColor instead. This feature was deprecated after v3.31.0-2.0.pre • lib/widgets/decks/deck_card_list_tab.dart:288:25 • deprecated_member_use
2026-02-28T17:40:57.5596078Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:303:39 • prefer_single_quotes
2026-02-28T17:40:57.5596881Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:309:112 • prefer_single_quotes
2026-02-28T17:40:57.5597695Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:311:110 • prefer_single_quotes
2026-02-28T17:40:57.5598492Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:313:113 • prefer_single_quotes
2026-02-28T17:40:57.5599300Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:315:115 • prefer_single_quotes
2026-02-28T17:40:57.5600120Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:362:31 • prefer_single_quotes
2026-02-28T17:40:57.5600920Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:377:31 • prefer_single_quotes
2026-02-28T17:40:57.5601707Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_list_tab.dart:387:122 • prefer_single_quotes
2026-02-28T17:40:57.5602600Z    info • Use 'const' with the constructor to improve performance • lib/widgets/decks/deck_card_picker.dart:44:31 • prefer_const_constructors
2026-02-28T17:40:57.5603630Z    info • Use 'const' with the constructor to improve performance • lib/widgets/decks/deck_card_picker.dart:58:38 • prefer_const_constructors
2026-02-28T17:40:57.5604501Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_picker.dart:375:21 • prefer_single_quotes
2026-02-28T17:40:57.5605307Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_picker.dart:381:23 • prefer_single_quotes
2026-02-28T17:40:57.5606091Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_picker.dart:382:23 • prefer_single_quotes
2026-02-28T17:40:57.5606885Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_picker.dart:418:53 • prefer_single_quotes
2026-02-28T17:40:57.5607674Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_picker.dart:445:15 • prefer_single_quotes
2026-02-28T17:40:57.5608506Z    info • Unnecessary use of multiple underscores • lib/widgets/decks/deck_card_picker.dart:456:35 • unnecessary_underscores
2026-02-28T17:40:57.5609329Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_picker.dart:491:53 • prefer_single_quotes
2026-02-28T17:40:57.5610119Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_picker.dart:517:15 • prefer_single_quotes
2026-02-28T17:40:57.5611019Z    info • Unnecessary use of multiple underscores • lib/widgets/decks/deck_card_picker.dart:526:35 • unnecessary_underscores
2026-02-28T17:40:57.5611852Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_picker.dart:637:21 • prefer_single_quotes
2026-02-28T17:40:57.5612641Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_picker.dart:644:25 • prefer_single_quotes
2026-02-28T17:40:57.5613530Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_picker.dart:697:20 • prefer_single_quotes
2026-02-28T17:40:57.5614323Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_picker.dart:698:20 • prefer_single_quotes
2026-02-28T17:40:57.5615114Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_card_picker.dart:709:25 • prefer_single_quotes
2026-02-28T17:40:57.5616127Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_card_title.dart:35:27 • deprecated_member_use
2026-02-28T17:40:57.5617318Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_card_title.dart:102:72 • deprecated_member_use
2026-02-28T17:40:57.5618547Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_card_title.dart:156:87 • deprecated_member_use
2026-02-28T17:40:57.5619694Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_card_title.dart:160:29 • deprecated_member_use
2026-02-28T17:40:57.5620843Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_card_title.dart:179:98 • deprecated_member_use
2026-02-28T17:40:57.5621990Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_card_title.dart:188:43 • deprecated_member_use
2026-02-28T17:40:57.5623200Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_card_title.dart:214:65 • deprecated_member_use
2026-02-28T17:40:57.5624352Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_card_title.dart:234:37 • deprecated_member_use
2026-02-28T17:40:57.5625315Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_financial_sheet.dart:157:40 • prefer_single_quotes
2026-02-28T17:40:57.5626145Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_financial_sheet.dart:168:40 • prefer_single_quotes
2026-02-28T17:40:57.5627162Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_financial_sheet.dart:187:53 • deprecated_member_use
2026-02-28T17:40:57.5628370Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_financial_sheet.dart:187:145 • deprecated_member_use
2026-02-28T17:40:57.5629472Z    info • Use 'const' with the constructor to improve performance • lib/widgets/decks/deck_financial_sheet.dart:195:33 • prefer_const_constructors
2026-02-28T17:40:57.5630371Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_share_preview.dart:28:22 • prefer_single_quotes
2026-02-28T17:40:57.5631289Z    info • Statements in an if should be enclosed in a block • lib/widgets/decks/deck_share_preview.dart:55:36 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5632305Z    info • Statements in an if should be enclosed in a block • lib/widgets/decks/deck_share_preview.dart:60:25 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5633466Z    info • Statements in an if should be enclosed in a block • lib/widgets/decks/deck_share_preview.dart:61:16 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5634707Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_share_preview.dart:104:67 • deprecated_member_use
2026-02-28T17:40:57.5635701Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_share_preview.dart:129:45 • prefer_single_quotes
2026-02-28T17:40:57.5636521Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_share_preview.dart:129:95 • prefer_single_quotes
2026-02-28T17:40:57.5637329Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_share_preview.dart:130:75 • prefer_single_quotes
2026-02-28T17:40:57.5638122Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_share_preview.dart:131:44 • prefer_single_quotes
2026-02-28T17:40:57.5638918Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_share_preview.dart:131:62 • prefer_single_quotes
2026-02-28T17:40:57.5639738Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_share_preview.dart:132:49 • prefer_single_quotes
2026-02-28T17:40:57.5640539Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_share_preview.dart:132:63 • prefer_single_quotes
2026-02-28T17:40:57.5641334Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_share_preview.dart:158:46 • prefer_single_quotes
2026-02-28T17:40:57.5642203Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_share_preview.dart:158:53 • prefer_single_quotes
2026-02-28T17:40:57.5643276Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_share_preview.dart:181:33 • deprecated_member_use
2026-02-28T17:40:57.5644248Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_share_preview.dart:182:25 • prefer_single_quotes
2026-02-28T17:40:57.5645066Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:99:21 • prefer_single_quotes
2026-02-28T17:40:57.5645779Z    info • Empty catch block • lib/widgets/decks/deck_stats_tab.dart:146:19 • empty_catches
2026-02-28T17:40:57.5646495Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:154:21 • prefer_single_quotes
2026-02-28T17:40:57.5647193Z    info • Empty catch block • lib/widgets/decks/deck_stats_tab.dart:184:19 • empty_catches
2026-02-28T17:40:57.5647860Z    info • Empty catch block • lib/widgets/decks/deck_stats_tab.dart:209:19 • empty_catches
2026-02-28T17:40:57.5648562Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:236:20 • prefer_single_quotes
2026-02-28T17:40:57.5649343Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:237:23 • prefer_single_quotes
2026-02-28T17:40:57.5650108Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:244:20 • prefer_single_quotes
2026-02-28T17:40:57.5650872Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:252:20 • prefer_single_quotes
2026-02-28T17:40:57.5651641Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:253:23 • prefer_single_quotes
2026-02-28T17:40:57.5652412Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:262:20 • prefer_single_quotes
2026-02-28T17:40:57.5653248Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:263:23 • prefer_single_quotes
2026-02-28T17:40:57.5654008Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:270:20 • prefer_single_quotes
2026-02-28T17:40:57.5654762Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:276:20 • prefer_single_quotes
2026-02-28T17:40:57.5655743Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_stats_tab.dart:302:44 • deprecated_member_use
2026-02-28T17:40:57.5656961Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_stats_tab.dart:310:42 • deprecated_member_use
2026-02-28T17:40:57.5657902Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:323:74 • prefer_single_quotes
2026-02-28T17:40:57.5658884Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_stats_tab.dart:337:27 • deprecated_member_use
2026-02-28T17:40:57.5660028Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_stats_tab.dart:338:127 • deprecated_member_use
2026-02-28T17:40:57.5660973Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:344:31 • prefer_single_quotes
2026-02-28T17:40:57.5661747Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:346:31 • prefer_single_quotes
2026-02-28T17:40:57.5662520Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:346:44 • prefer_single_quotes
2026-02-28T17:40:57.5663388Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:386:64 • prefer_single_quotes
2026-02-28T17:40:57.5664281Z    info • Use 'const' with the constructor to improve performance • lib/widgets/decks/deck_stats_tab.dart:405:44 • prefer_const_constructors
2026-02-28T17:40:57.5665218Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:469:17 • prefer_single_quotes
2026-02-28T17:40:57.5666202Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_stats_tab.dart:498:45 • deprecated_member_use
2026-02-28T17:40:57.5667155Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:512:57 • prefer_single_quotes
2026-02-28T17:40:57.5668039Z    info • Use 'const' with the constructor to improve performance • lib/widgets/decks/deck_stats_tab.dart:518:100 • prefer_const_constructors
2026-02-28T17:40:57.5668924Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:544:28 • prefer_single_quotes
2026-02-28T17:40:57.5669707Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:544:60 • prefer_single_quotes
2026-02-28T17:40:57.5670477Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:555:82 • prefer_single_quotes
2026-02-28T17:40:57.5671254Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:567:103 • prefer_single_quotes
2026-02-28T17:40:57.5672024Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_stats_tab.dart:583:61 • prefer_single_quotes
2026-02-28T17:40:57.5672825Z warning • The value of the field '_errorMsg' isn't used • lib/widgets/decks/deck_suggestions_tab.dart:36:11 • unused_field
2026-02-28T17:40:57.5673828Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_suggestions_tab.dart:56:28 • prefer_single_quotes
2026-02-28T17:40:57.5674660Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_suggestions_tab.dart:77:54 • prefer_single_quotes
2026-02-28T17:40:57.5675486Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_suggestions_tab.dart:144:33 • prefer_single_quotes
2026-02-28T17:40:57.5676327Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_suggestions_tab.dart:154:36 • prefer_single_quotes
2026-02-28T17:40:57.5677143Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_suggestions_tab.dart:154:58 • prefer_single_quotes
2026-02-28T17:40:57.5677955Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_suggestions_tab.dart:165:33 • prefer_single_quotes
2026-02-28T17:40:57.5678842Z    info • Unnecessary use of 'toList' in a spread • lib/widgets/decks/deck_suggestions_tab.dart:185:77 • unnecessary_to_list_in_spreads
2026-02-28T17:40:57.5679719Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_suggestions_tab.dart:190:30 • prefer_single_quotes
2026-02-28T17:40:57.5680840Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_suggestions_tab.dart:204:27 • deprecated_member_use
2026-02-28T17:40:57.5681836Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_suggestions_tab.dart:223:24 • prefer_single_quotes
2026-02-28T17:40:57.5682707Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_suggestions_tab.dart:246:28 • prefer_single_quotes
2026-02-28T17:40:57.5683731Z    info • Use 'const' for final variables initialized to a constant value • lib/widgets/decks/deck_visual_share_list.dart:46:5 • prefer_const_declarations
2026-02-28T17:40:57.5684659Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:92:38 • prefer_single_quotes
2026-02-28T17:40:57.5685687Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_visual_share_list.dart:104:47 • deprecated_member_use
2026-02-28T17:40:57.5686708Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:109:27 • prefer_single_quotes
2026-02-28T17:40:57.5687539Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:132:50 • prefer_single_quotes
2026-02-28T17:40:57.5688364Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:132:68 • prefer_single_quotes
2026-02-28T17:40:57.5689188Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:133:55 • prefer_single_quotes
2026-02-28T17:40:57.5690008Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:133:69 • prefer_single_quotes
2026-02-28T17:40:57.5690830Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:134:50 • prefer_single_quotes
2026-02-28T17:40:57.5691656Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:134:95 • prefer_single_quotes
2026-02-28T17:40:57.5692478Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:159:52 • prefer_single_quotes
2026-02-28T17:40:57.5693359Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:159:59 • prefer_single_quotes
2026-02-28T17:40:57.5694195Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:192:38 • prefer_single_quotes
2026-02-28T17:40:57.5695014Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:215:42 • prefer_single_quotes
2026-02-28T17:40:57.5696042Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_visual_share_list.dart:233:33 • deprecated_member_use
2026-02-28T17:40:57.5697046Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:236:17 • prefer_single_quotes
2026-02-28T17:40:57.5697989Z    info • Unnecessary use of multiple underscores • lib/widgets/decks/deck_visual_share_list.dart:257:24 • unnecessary_underscores
2026-02-28T17:40:57.5698906Z    info • Unnecessary use of multiple underscores • lib/widgets/decks/deck_visual_share_list.dart:257:27 • unnecessary_underscores
2026-02-28T17:40:57.5699987Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/deck_visual_share_list.dart:307:57 • deprecated_member_use
2026-02-28T17:40:57.5700988Z    info • Unnecessary use of double quotes • lib/widgets/decks/deck_visual_share_list.dart:361:29 • prefer_single_quotes
2026-02-28T17:40:57.5701930Z    info • Statements in an if should be enclosed in a block • lib/widgets/decks/deck_visual_share_list.dart:398:34 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5702967Z    info • Statements in an if should be enclosed in a block • lib/widgets/decks/deck_visual_share_list.dart:399:43 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5704079Z    info • Statements in an if should be enclosed in a block • lib/widgets/decks/deck_visual_share_list.dart:400:47 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5705122Z    info • Statements in an if should be enclosed in a block • lib/widgets/decks/deck_visual_share_list.dart:401:42 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5706224Z    info • Statements in an if should be enclosed in a block • lib/widgets/decks/deck_visual_share_list.dart:402:42 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5707250Z    info • Statements in an if should be enclosed in a block • lib/widgets/decks/deck_visual_share_list.dart:403:43 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5708286Z    info • Statements in an if should be enclosed in a block • lib/widgets/decks/deck_visual_share_list.dart:404:46 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5709315Z    info • Statements in an if should be enclosed in a block • lib/widgets/decks/deck_visual_share_list.dart:405:41 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5710350Z    info • Statements in a for should be enclosed in a block • lib/widgets/decks/deck_visual_share_list.dart:410:35 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5711390Z    info • Statements in an if should be enclosed in a block • lib/widgets/decks/deck_visual_share_list.dart:430:23 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5712413Z    info • Statements in an if should be enclosed in a block • lib/widgets/decks/deck_visual_share_list.dart:431:14 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5713610Z    info • Use 'const' with the constructor to improve performance • lib/widgets/decks/draw_test_simulator.dart:166:19 • prefer_const_constructors
2026-02-28T17:40:57.5714517Z    info • Unnecessary use of double quotes • lib/widgets/decks/draw_test_simulator.dart:166:24 • prefer_single_quotes
2026-02-28T17:40:57.5715439Z    info • Use 'const' with the constructor to improve performance • lib/widgets/decks/draw_test_simulator.dart:166:56 • prefer_const_constructors
2026-02-28T17:40:57.5716353Z    info • Unnecessary use of double quotes • lib/widgets/decks/draw_test_simulator.dart:188:43 • prefer_single_quotes
2026-02-28T17:40:57.5717386Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/draw_test_simulator.dart:201:65 • deprecated_member_use
2026-02-28T17:40:57.5718570Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/decks/draw_test_simulator.dart:201:97 • deprecated_member_use
2026-02-28T17:40:57.5719563Z    info • Unnecessary use of double quotes • lib/widgets/decks/draw_test_simulator.dart:227:44 • prefer_single_quotes
2026-02-28T17:40:57.5720410Z    info • Unnecessary use of double quotes • lib/widgets/decks/draw_test_simulator.dart:288:13 • prefer_single_quotes
2026-02-28T17:40:57.5721528Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/dice_roll_dialog.dart:71:115 • deprecated_member_use
2026-02-28T17:40:57.5722730Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/dice_roll_dialog.dart:97:86 • deprecated_member_use
2026-02-28T17:40:57.5723825Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/dice_roll_dialog.dart:113:36 • prefer_single_quotes
2026-02-28T17:40:57.5724672Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/dice_roll_dialog.dart:125:43 • prefer_single_quotes
2026-02-28T17:40:57.5725511Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/dice_roll_dialog.dart:125:52 • prefer_single_quotes
2026-02-28T17:40:57.5726564Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/dice_roll_dialog.dart:138:191 • deprecated_member_use
2026-02-28T17:40:57.5727647Z    info • The private field _selectedProfiles could be 'final' • lib/widgets/life_counter/game_setup_modal.dart:30:18 • prefer_final_fields
2026-02-28T17:40:57.5728535Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:64:18 • prefer_single_quotes
2026-02-28T17:40:57.5729437Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:74:34 • prefer_single_quotes
2026-02-28T17:40:57.5730252Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:76:34 • prefer_single_quotes
2026-02-28T17:40:57.5731117Z    info • Unnecessary use of multiple underscores • lib/widgets/life_counter/game_setup_modal.dart:85:38 • unnecessary_underscores
2026-02-28T17:40:57.5731985Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:106:27 • prefer_single_quotes
2026-02-28T17:40:57.5732815Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:139:31 • prefer_single_quotes
2026-02-28T17:40:57.5733699Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:145:31 • prefer_single_quotes
2026-02-28T17:40:57.5734752Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/game_setup_modal.dart:154:27 • deprecated_member_use
2026-02-28T17:40:57.5735757Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:163:38 • prefer_single_quotes
2026-02-28T17:40:57.5736579Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:167:20 • prefer_single_quotes
2026-02-28T17:40:57.5737396Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:182:88 • prefer_single_quotes
2026-02-28T17:40:57.5738222Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:212:27 • prefer_single_quotes
2026-02-28T17:40:57.5739040Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:220:35 • prefer_single_quotes
2026-02-28T17:40:57.5739874Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:235:35 • prefer_single_quotes
2026-02-28T17:40:57.5740715Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:261:49 • prefer_single_quotes
2026-02-28T17:40:57.5741547Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:261:68 • prefer_single_quotes
2026-02-28T17:40:57.5742373Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:268:64 • prefer_single_quotes
2026-02-28T17:40:57.5743261Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:273:26 • prefer_single_quotes
2026-02-28T17:40:57.5744184Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:284:26 • prefer_single_quotes
2026-02-28T17:40:57.5745102Z    info • Don't use 'BuildContext's across async gaps • lib/widgets/life_counter/game_setup_modal.dart:302:33 • use_build_context_synchronously
2026-02-28T17:40:57.5746014Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:304:35 • prefer_single_quotes
2026-02-28T17:40:57.5746845Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:306:83 • prefer_single_quotes
2026-02-28T17:40:57.5748019Z    info • 'value' is deprecated and shouldn't be used. Use component accessors like .r or .g, or toARGB32 for an explicit conversion • lib/widgets/life_counter/game_setup_modal.dart:313:47 • deprecated_member_use
2026-02-28T17:40:57.5749197Z    info • Don't use 'BuildContext's across async gaps • lib/widgets/life_counter/game_setup_modal.dart:322:33 • use_build_context_synchronously
2026-02-28T17:40:57.5750106Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:325:33 • prefer_single_quotes
2026-02-28T17:40:57.5751142Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/game_setup_modal.dart:347:31 • deprecated_member_use
2026-02-28T17:40:57.5752219Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:350:52 • prefer_single_quotes
2026-02-28T17:40:57.5753429Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/game_setup_modal.dart:368:54 • deprecated_member_use
2026-02-28T17:40:57.5754446Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:377:24 • prefer_single_quotes
2026-02-28T17:40:57.5755288Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:394:33 • prefer_single_quotes
2026-02-28T17:40:57.5756331Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/game_setup_modal.dart:395:64 • deprecated_member_use
2026-02-28T17:40:57.5757534Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/game_setup_modal.dart:397:47 • deprecated_member_use
2026-02-28T17:40:57.5758755Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/game_setup_modal.dart:421:45 • deprecated_member_use
2026-02-28T17:40:57.5759957Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/game_setup_modal.dart:423:64 • deprecated_member_use
2026-02-28T17:40:57.5760958Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:433:44 • prefer_single_quotes
2026-02-28T17:40:57.5761794Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:435:62 • prefer_single_quotes
2026-02-28T17:40:57.5762823Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/game_setup_modal.dart:463:79 • deprecated_member_use
2026-02-28T17:40:57.5763940Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:477:29 • prefer_single_quotes
2026-02-28T17:40:57.5764968Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/game_setup_modal.dart:477:77 • deprecated_member_use
2026-02-28T17:40:57.5766267Z    info • 'value' is deprecated and shouldn't be used. Use component accessors like .r or .g, or toARGB32 for an explicit conversion • lib/widgets/life_counter/game_setup_modal.dart:485:49 • deprecated_member_use
2026-02-28T17:40:57.5767357Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/game_setup_modal.dart:500:35 • prefer_single_quotes
2026-02-28T17:40:57.5768334Z    info • Don't use 'BuildContext's across async gaps • lib/widgets/life_counter/player_zone.dart:178:23 • use_build_context_synchronously
2026-02-28T17:40:57.5769202Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/player_zone.dart:181:18 • prefer_single_quotes
2026-02-28T17:40:57.5770021Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/player_zone.dart:211:21 • prefer_single_quotes
2026-02-28T17:40:57.5770814Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/player_zone.dart:219:27 • prefer_single_quotes
2026-02-28T17:40:57.5771608Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/player_zone.dart:227:33 • prefer_single_quotes
2026-02-28T17:40:57.5772409Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/player_zone.dart:240:24 • prefer_single_quotes
2026-02-28T17:40:57.5773496Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/player_zone.dart:253:52 • deprecated_member_use
2026-02-28T17:40:57.5774681Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/player_zone.dart:315:51 • deprecated_member_use
2026-02-28T17:40:57.5775945Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/player_zone.dart:321:64 • deprecated_member_use
2026-02-28T17:40:57.5777121Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/player_zone.dart:334:137 • deprecated_member_use
2026-02-28T17:40:57.5778298Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/player_zone.dart:349:89 • deprecated_member_use
2026-02-28T17:40:57.5779477Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/player_zone.dart:383:134 • deprecated_member_use
2026-02-28T17:40:57.5780446Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/player_zone.dart:462:29 • prefer_single_quotes
2026-02-28T17:40:57.5781478Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/player_zone.dart:516:47 • deprecated_member_use
2026-02-28T17:40:57.5782442Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/player_zone.dart:518:18 • prefer_single_quotes
2026-02-28T17:40:57.5783594Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/life_counter/player_zone.dart:518:58 • deprecated_member_use
2026-02-28T17:40:57.5784570Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/player_zone.dart:613:18 • prefer_single_quotes
2026-02-28T17:40:57.5785383Z    info • Unnecessary use of double quotes • lib/widgets/life_counter/player_zone.dart:620:27 • prefer_single_quotes
2026-02-28T17:40:57.5786237Z    info • Unnecessary use of multiple underscores • lib/widgets/life_counter/player_zone.dart:653:91 • unnecessary_underscores
2026-02-28T17:40:57.5787129Z    info • Unnecessary use of multiple underscores • lib/widgets/life_counter/player_zone.dart:653:94 • unnecessary_underscores
2026-02-28T17:40:57.5788470Z    info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre • lib/widgets/search/search_filter_modal.dart:125:25 • deprecated_member_use
2026-02-28T17:40:57.5789944Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/search/search_filter_modal.dart:182:59 • deprecated_member_use
2026-02-28T17:40:57.5791224Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/search/skyrim_sneak_loader.dart:98:31 • deprecated_member_use
2026-02-28T17:40:57.5792237Z    info • Unnecessary use of double quotes • lib/widgets/search/universal_filter_modal.dart:114:22 • prefer_single_quotes
2026-02-28T17:40:57.5793082Z    info • Unnecessary use of double quotes • lib/widgets/search/universal_filter_modal.dart:115:65 • prefer_single_quotes
2026-02-28T17:40:57.5794005Z    info • Unnecessary use of double quotes • lib/widgets/search/universal_filter_modal.dart:126:25 • prefer_single_quotes
2026-02-28T17:40:57.5794853Z    info • Unnecessary use of double quotes • lib/widgets/search/universal_filter_modal.dart:127:25 • prefer_single_quotes
2026-02-28T17:40:57.5795683Z    info • Unnecessary use of double quotes • lib/widgets/search/universal_filter_modal.dart:141:42 • prefer_single_quotes
2026-02-28T17:40:57.5796509Z    info • Unnecessary use of double quotes • lib/widgets/search/universal_filter_modal.dart:159:38 • prefer_single_quotes
2026-02-28T17:40:57.5797351Z    info • Unnecessary use of double quotes • lib/widgets/search/universal_filter_modal.dart:178:42 • prefer_single_quotes
2026-02-28T17:40:57.5798180Z    info • Unnecessary use of double quotes • lib/widgets/search/universal_filter_modal.dart:180:36 • prefer_single_quotes
2026-02-28T17:40:57.5799210Z    info • Statements in an if should be enclosed in a block • lib/widgets/search/universal_filter_modal.dart:191:44 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5800270Z    info • Statements in an if should be enclosed in a block • lib/widgets/search/universal_filter_modal.dart:192:40 • curly_braces_in_flow_control_structures
2026-02-28T17:40:57.5801410Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/search/universal_filter_modal.dart:196:64 • deprecated_member_use
2026-02-28T17:40:57.5802430Z    info • Unnecessary use of double quotes • lib/widgets/search/universal_filter_modal.dart:217:38 • prefer_single_quotes
2026-02-28T17:40:57.5803353Z    info • Unnecessary use of double quotes • lib/widgets/search/universal_filter_modal.dart:227:42 • prefer_single_quotes
2026-02-28T17:40:57.5804190Z    info • Unnecessary use of double quotes • lib/widgets/search/universal_filter_modal.dart:232:42 • prefer_single_quotes
2026-02-28T17:40:57.5805250Z    info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss • lib/widgets/search/universal_filter_modal.dart:247:50 • deprecated_member_use
2026-02-28T17:40:57.5806272Z    info • Unnecessary use of double quotes • lib/widgets/search/universal_filter_modal.dart:259:42 • prefer_single_quotes
2026-02-28T17:40:57.5807102Z    info • Unnecessary use of double quotes • lib/widgets/search/universal_filter_modal.dart:288:31 • prefer_single_quotes
2026-02-28T17:40:57.5807940Z warning • The asset file 'assets/json/oracle-cards.json' doesn't exist • pubspec.yaml:124:7 • asset_does_not_exist
2026-02-28T17:40:57.5808906Z    info • Use 'const' with the constructor to improve performance • test/controllers/card_search_controller_test.dart:111:24 • prefer_const_constructors
2026-02-28T17:40:57.5809964Z    info • Use 'const' with the constructor to improve performance • test/controllers/card_search_controller_test.dart:118:24 • prefer_const_constructors
2026-02-28T17:40:57.5811025Z    info • Use 'const' with the constructor to improve performance • test/controllers/card_search_controller_test.dart:125:24 • prefer_const_constructors
2026-02-28T17:40:57.5812057Z    info • Use 'const' with the constructor to improve performance • test/controllers/card_search_controller_test.dart:132:24 • prefer_const_constructors
2026-02-28T17:40:57.5813081Z    info • Use 'const' with the constructor to improve performance • test/controllers/card_search_controller_test.dart:139:24 • prefer_const_constructors
2026-02-28T17:40:57.5814180Z    info • Use 'const' with the constructor to improve performance • test/controllers/card_search_controller_test.dart:146:24 • prefer_const_constructors
2026-02-28T17:40:57.5815311Z    info • Use 'const' with the constructor to improve performance • test/controllers/card_search_controller_test.dart:153:24 • prefer_const_constructors
2026-02-28T17:40:57.5816376Z    info • Use 'const' for final variables initialized to a constant value • test/controllers/card_search_controller_test.dart:245:7 • prefer_const_declarations
2026-02-28T17:40:57.5817438Z    info • Use 'const' with the constructor to improve performance • test/controllers/card_search_controller_test.dart:259:26 • prefer_const_constructors
2026-02-28T17:40:57.5818465Z    info • Use 'const' with the constructor to improve performance • test/controllers/card_search_controller_test.dart:300:24 • prefer_const_constructors
2026-02-28T17:40:57.5819509Z    info • Use 'const' with the constructor to improve performance • test/controllers/card_search_controller_test.dart:307:24 • prefer_const_constructors
2026-02-28T17:40:57.5820447Z    info • Unnecessary use of double quotes • test/controllers/card_search_controller_test.dart:311:24 • prefer_single_quotes
2026-02-28T17:40:57.5821405Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:84:21 • prefer_const_constructors
2026-02-28T17:40:57.5822435Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:85:24 • prefer_const_constructors
2026-02-28T17:40:57.5823597Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:91:21 • prefer_const_constructors
2026-02-28T17:40:57.5824627Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:92:24 • prefer_const_constructors
2026-02-28T17:40:57.5825647Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:98:21 • prefer_const_constructors
2026-02-28T17:40:57.5826676Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:99:24 • prefer_const_constructors
2026-02-28T17:40:57.5827714Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:105:21 • prefer_const_constructors
2026-02-28T17:40:57.5828760Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:106:24 • prefer_const_constructors
2026-02-28T17:40:57.5829799Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:112:21 • prefer_const_constructors
2026-02-28T17:40:57.5830835Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:113:24 • prefer_const_constructors
2026-02-28T17:40:57.5831863Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:209:26 • prefer_const_constructors
2026-02-28T17:40:57.5832906Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:222:21 • prefer_const_constructors
2026-02-28T17:40:57.5834053Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:223:24 • prefer_const_constructors
2026-02-28T17:40:57.5835097Z    info • Use 'const' with the constructor to improve performance • test/controllers/collection_controller_test.dart:225:26 • prefer_const_constructors
2026-02-28T17:40:57.5836145Z    info • Use 'const' with the constructor to improve performance • test/controllers/set_detail_controller_test.dart:120:24 • prefer_const_constructors
2026-02-28T17:40:57.5837181Z    info • Use 'const' with the constructor to improve performance • test/controllers/set_detail_controller_test.dart:127:24 • prefer_const_constructors
2026-02-28T17:40:57.5838210Z    info • Use 'const' with the constructor to improve performance • test/controllers/set_detail_controller_test.dart:286:26 • prefer_const_constructors
2026-02-28T17:40:57.5839295Z    info • Use 'const' with the constructor to improve performance • test/data/app_database_test.dart:335:30 • prefer_const_constructors
2026-02-28T17:40:57.5840227Z    info • Use 'const' with the constructor to improve performance • test/data/app_database_test.dart:349:30 • prefer_const_constructors
2026-02-28T17:40:57.5841159Z    info • Use 'const' with the constructor to improve performance • test/data/app_database_test.dart:353:30 • prefer_const_constructors
2026-02-28T17:40:57.5842090Z    info • Use 'const' with the constructor to improve performance • test/data/app_database_test.dart:364:30 • prefer_const_constructors
2026-02-28T17:40:57.5843011Z    info • Use 'const' with the constructor to improve performance • test/data/app_database_test.dart:365:30 • prefer_const_constructors
2026-02-28T17:40:57.5844132Z    info • The local variable '_createAndGetDeckId' starts with an underscore • test/services/deck_service_test.dart:25:18 • no_leading_underscores_for_local_identifiers
2026-02-28T17:40:57.5845215Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:137:23 • prefer_const_constructors
2026-02-28T17:40:57.5846200Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:144:23 • prefer_const_constructors
2026-02-28T17:40:57.5847282Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:150:23 • prefer_const_constructors
2026-02-28T17:40:57.5847771Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:159:23 • prefer_const_constructors
2026-02-28T17:40:57.5848248Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:165:23 • prefer_const_constructors
2026-02-28T17:40:57.5848733Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:174:23 • prefer_const_constructors
2026-02-28T17:40:57.5849212Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:180:23 • prefer_const_constructors
2026-02-28T17:40:57.5849701Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:189:23 • prefer_const_constructors
2026-02-28T17:40:57.5850188Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:195:23 • prefer_const_constructors
2026-02-28T17:40:57.5850670Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:202:23 • prefer_const_constructors
2026-02-28T17:40:57.5851148Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:210:23 • prefer_const_constructors
2026-02-28T17:40:57.5851699Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:217:23 • prefer_const_constructors
2026-02-28T17:40:57.5852188Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:224:23 • prefer_const_constructors
2026-02-28T17:40:57.5852677Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:234:23 • prefer_const_constructors
2026-02-28T17:40:57.5853231Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:241:23 • prefer_const_constructors
2026-02-28T17:40:57.5853718Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:248:23 • prefer_const_constructors
2026-02-28T17:40:57.5854206Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:257:23 • prefer_const_constructors
2026-02-28T17:40:57.5854692Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:264:23 • prefer_const_constructors
2026-02-28T17:40:57.5855175Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:271:23 • prefer_const_constructors
2026-02-28T17:40:57.5855723Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:277:23 • prefer_const_constructors
2026-02-28T17:40:57.5856207Z    info • Use 'const' with the constructor to improve performance • test/services/local_card_search_test.dart:290:23 • prefer_const_constructors
2026-02-28T17:40:57.5856222Z 
2026-02-28T17:40:57.5856400Z 1042 issues found. (ran in 25.9s)
2026-02-28T17:40:57.5866525Z ##[error]Process completed with exit code 1.
2026-02-28T17:40:57.6069543Z Post job cleanup.
2026-02-28T17:40:57.6128858Z Post job cleanup.
2026-02-28T17:40:57.7777861Z Post job cleanup.
2026-02-28T17:40:57.8660312Z [command]/usr/bin/git version
2026-02-28T17:40:57.8693837Z git version 2.53.0
2026-02-28T17:40:57.8732135Z Temporarily overriding HOME='/home/runner/work/_temp/97e1a3d1-e33e-4b8d-abbc-0d3e2ee6224d' before making global git config changes
2026-02-28T17:40:57.8733088Z Adding repository directory to the temporary git global config as a safe directory
2026-02-28T17:40:57.8746102Z [command]/usr/bin/git config --global --add safe.directory /home/runner/work/magic_compagnion/magic_compagnion
2026-02-28T17:40:57.8777087Z [command]/usr/bin/git config --local --name-only --get-regexp core\.sshCommand
2026-02-28T17:40:57.8805305Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'core\.sshCommand' && git config --local --unset-all 'core.sshCommand' || :"
2026-02-28T17:40:57.8988019Z [command]/usr/bin/git config --local --name-only --get-regexp http\.https\:\/\/github\.com\/\.extraheader
2026-02-28T17:40:57.9006784Z http.https://github.com/.extraheader
2026-02-28T17:40:57.9017452Z [command]/usr/bin/git config --local --unset-all http.https://github.com/.extraheader
2026-02-28T17:40:57.9041997Z [command]/usr/bin/git submodule foreach --recursive sh -c "git config --local --name-only --get-regexp 'http\.https\:\/\/github\.com\/\.extraheader' && git config --local --unset-all 'http.https://github.com/.extraheader' || :"
2026-02-28T17:40:57.9214067Z [command]/usr/bin/git config --local --name-only --get-regexp ^includeIf\.gitdir:
2026-02-28T17:40:57.9239496Z [command]/usr/bin/git submodule foreach --recursive git config --local --show-origin --name-only --get-regexp remote.origin.url
2026-02-28T17:40:57.9505180Z Cleaning up orphan processes