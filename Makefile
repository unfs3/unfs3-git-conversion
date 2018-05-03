SVNURI = svn+ssh://derfian@svn.code.sf.net/p/unfs3/code
SVNMIRROR = unfs3.svn
SVNMIRRORURI = file://$(CURDIR)/$(SVNMIRROR)
GITREPO = conv
FINALREPO = unfs3.git
GIT = cd $(GITREPO) && git
FILTER-BRANCH = $(GIT) filter-branch -f

all: 99-complete
.PHONY: all clean

00-svn-repo-stamp:
	svnsync init --allow-non-empty $(SVNMIRRORURI) $(SVNURI)
	@touch $@

10-svn-sync-stamp: 00-svn-repo-stamp
	svnsync sync $(SVNMIRRORURI) $(SVNURI)
	@touch $@

20-git-repo-stamp: 10-svn-sync-stamp
	git svn init -s \
	             --prefix=svn/ \
	             $(SVNMIRRORURI) \
	             $(GITREPO)
	$(GIT) svn fetch
	@touch $@

# This commit is not a merge, but it's impossible to tell apart from a
# merge so we need to remove it from the parent list of a commit.

30-filter-parents: 20-git-repo-stamp
	$(FILTER-BRANCH) \
	    --parent-filter 'sed "s/-p $(shell $(GIT) log --format="%H" --grep="Temporarily move away trunk, to be able to move trunk/unfs3 in place.")//g"' \
	    --tag-name-filter 'cat' \
	    -- --all
	@touch $@

# Remove all CVSROOT remnants.

31-filter-cvsroot: 30-filter-parents
	$(FILTER-BRANCH) --tree-filter 'rm -rf CVSROOT unfs3/CVSROOT' \
	                 --tag-name-filter 'cat' \
	                 --prune-empty \
	                 -- --all
	@touch $@

# Move everything into a subdirectory and then run a
# subdirectory-filter. This was the best way to get everything in
# proper order.

32-filter-subdirectory: 31-filter-cvsroot
	$(FILTER-BRANCH) --tree-filter 'test -d unfs3 || \
	                                 (mkdir unfs3; \
	                                  for f in *; do \
	                                    test $${f} = "unfs3" && continue; \
	                                    mv $${f} unfs3/; \
	                                  done)' \
	                 --tag-name-filter 'cat' -- --all

	$(FILTER-BRANCH) --subdirectory-filter 'unfs3' \
	                 --tag-name-filter 'cat' -- --all
	@touch $@

# Merge branches together. This requires a bit of repo-specific
# knowledge.

60-branch-win32-2: 32-filter-subdirectory
	$(FILTER-BRANCH) --parent-filter 'test $$GIT_COMMIT = $(shell $(GIT) log --format="%H" --grep="/trunk@369" master) && \
	                 echo "$$* -p $(shell $(GIT) rev-parse refs/remotes/svn/win32-2)" || cat' \
	                 --tag-name-filter 'cat' -- --all
	@touch $@

# The removable-fsidhash branch is a mess. It looks to be mostly
# merged by hand(!), so we'll just do the easy thing and ignore it
# completely.

#61-branch-removable-fsidhash: 60-branch-win32-2

# Create a new branch for removable-support as it's not merged.

62-branch-removable-support: 60-branch-win32-2
	$(GIT) branch removable-support refs/remotes/svn/removable-support
	@touch $@

# Make git tags from refs/remotes/svn/tags.

70-fixup-tags: 62-branch-removable-support
	$(GIT) for-each-ref --format='%(refname)' refs/remotes/svn/tags/ | \
	while read tag; do \
	    git tag $$(echo $${tag} | \
		sed -e 's@refs/remotes/svn/tags/@@g' \
                    -e 's@unfs3-0-9-@unfs3-0.9.@g') \
	    $${tag}; \
	done
	@touch $@

# Change git-svn metadata to the real URI.

80-change-svn-server-uri: 70-fixup-tags
	$(FILTER-BRANCH) --msg-filter "sed -e 's|file:///local/home/derfian/unfs3-git|svn://svn.code.sf.net/p/unfs3/code|g'" \
	                 --tag-name-filter 'cat' -- --all
	@touch $@

# Fix the author information to real names, not CVS or SVN usernames.

85-author-metadata: 80-change-svn-server-uri
	$(FILTER-BRANCH) --env-filter ' \
	  if test "$$GIT_AUTHOR_NAME" = "_cvs_pascal"; then \
	    export GIT_AUTHOR_NAME="Pascal Schmidt"; \
	    export GIT_AUTHOR_EMAIL="unfs3-server@ewetel.net"; \
            export GIT_COMMITTER_NAME="$$GIT_AUTHOR_NAME"; \
            export GIT_COMMITTER_EMAIL="$$GIT_AUTHOR_EMAIL"; \
	\
	  elif test "$$GIT_AUTHOR_NAME" = "peter" -o "$$GIT_AUTHOR_NAME" = "astrand"; then \
	    export GIT_AUTHOR_NAME="Peter Åstrand"; \
	    export GIT_AUTHOR_EMAIL="astrand@cendio.se"; \
            export GIT_COMMITTER_NAME="$$GIT_AUTHOR_NAME"; \
            export GIT_COMMITTER_EMAIL="$$GIT_AUTHOR_EMAIL"; \
	\
	  elif test "$$GIT_AUTHOR_NAME" = "derfian"; then \
	    export GIT_AUTHOR_NAME="Karl Mikaelsson"; \
	    export GIT_AUTHOR_EMAIL="derfian@cendio.se"; \
            export GIT_COMMITTER_NAME="$$GIT_AUTHOR_NAME"; \
            export GIT_COMMITTER_EMAIL="$$GIT_AUTHOR_EMAIL"; \
	\
	  elif test "$$GIT_AUTHOR_NAME" = "ossman_"; then \
	    export GIT_AUTHOR_NAME="Pierre Ossman"; \
	    export GIT_AUTHOR_EMAIL="ossman@cendio.se"; \
            export GIT_COMMITTER_NAME="$$GIT_AUTHOR_NAME"; \
            export GIT_COMMITTER_EMAIL="$$GIT_AUTHOR_EMAIL"; \
	  fi' --tag-name-filter 'cat' -- --all
	@touch $@

# Clean the leftovers from filter-branches

90-cleanup-original-ref: 85-author-metadata
	rm -rf $(GITREPO)/.git/refs/original
	@touch $@

91-cleanup-tags: 90-cleanup-original-ref
	$(GIT) tag -d myindentation
	$(GIT) tag -d password-support

# We're done!

95-clone-to-new-repo: 91-cleanup-tags
	git clone 'file://$(CURDIR)/$(GITREPO)' $(FINALREPO)
	@touch $@

96-set-github-upstream: 95-clone-to-new-repo
	(cd $(FINALREPO) && \
		git remote remove origin && \
		git remote add origin 'git@github.com:unfs3/unfs3.git')
	@touch $@

99-complete: 96-set-github-upstream
	@echo "Done! Check out the git repo in $(FINALREPO)"
	@echo "Push to github by:"
	@echo " cd $(FINALREPO) && git push -u --tags origin master"
	@touch $@

clean:
	rm -rf $(GITREPO) $(FINALREPO)
	rm -f 00-svn-repo-stamp \
	      10-svn-sync-stamp \
	      20-git-repo-full-stamp \
	      20-git-repo-stamp \
	      30-filter-parents \
	      31-filter-cvsroot \
	      32-filter-subdirectory \
	      40-noop \
	      50-remove-branches \
	      60-branch-win32-2 \
	      62-branch-removable-support \
	      69-branches-complete \
	      70-fixup-tags \
	      80-change-svn-server-uri \
	      85-author-metadata \
	      90-cleanup-original-ref \
	      91-cleanup-tags \
	      99-complete
