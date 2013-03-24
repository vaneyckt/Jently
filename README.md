# Jently
[![Build Status](https://travis-ci.org/jwg2s/Jently.png?branch=develop)](https://travis-ci.org/jwg2s/Jently)

Jently is a Ruby app that makes it possible for Jenkins to run tests on open pull requests on Github. Jently itself acts as a mediator between Jenkins and Github. It talks to Github to get open pull requests, creates a testing branches and instructs Jenkins to run tests on each branch. After Jenkins has finished testing the branch, Jently collects the result and updates the status of the relevant pull request commit through the Github API.

Why use Jently over Travis CI?  Jently can be used with closed source repositories, something that Travis CI is only in the beginning stages of supporting.

## Getting Started

There are 5 small steps involved in getting Jently up and running. These steps assume you have a recent version of Ruby installed and have sufficient access to your Jenkins CI so as to add builds.

### Installing the software

Jently currently runs as a standalone app and must be cloned through Git:

    git clone git@github.com:jwg2s/Jently.git

### Modifying your Jenkins CI

You will need to setup a parameterized Jenkins build for testing pull requests. Jently will instruct Jenkins to use this build for running tests on an open pull request. You can tell Jently about this build by modifying its configuration file.

On the Configure build screen of your job, you'll want to check the 'This build is parameterized' checkbox and add a 'branch', 'repository', and 'id' parameter. The order of the parameters is important. It should look like this:

![image](http://imgur.com/5Q3iA.png)

Further down on the Configure build screen you can specify your Source Code Management settings. Make sure that your branch specifier is set to '$branch' and that your repository url is set to '$repository'. It should look like this:

![image](http://imgur.com/2a2A5.png)

You can optionally add the Jenkins Text Finder plugin to more accurately mark builds as Stable vs. Unstable.

![image](http://imgur.com/DbvknLj.png)

### Modifying the configuration file

A sample configuration file can be found in the /config directory. There are a few configuration details that you will need to specify before running Jently. The comments in the file should hopefully make it easy to get everything set up right.

### Running Jently

Navigate into the Jently folder and run:

    ruby jently_control.rb start

This command will start Jently as a daemon process in the background. If this is your first run, Jently will start by cloning the specified repository into the /repositories directory, and will also create a .yaml file in the /db directory to help keep track of pull requests.


## Features

### Merged Builds
Jently tests the merged version of a pull request rather than just the feature branch. It takes into account all changes made upstream after a feature branch was created.  You can also configure the default branch that Jently should base the build off of (e.g. master, develop, etc)

### Automatic Re-Testing
Jently automatically re-runs tests whenever new commits are added to either the pull request itself or the branch that the pull request needs to be merged into.  Each latest commit associated with a new batch of commits is marked as stable or unstable.

![image](http://imgur.com/B16IBjO.png)

### Github API
Jently uses the [Github Commit Status API](https://github.com/blog/1227-commit-status-api) to update the status of the last commit of a pull request. Whenever possible, a status update contains a link to the Jenkins job that was run to ascertain the correct status.

## Contributions
To support the project:

Use Jently to build any of your apps with Jenkins and let us know if you encounter anything that's broken or missing. A failing spec is awesome. A pull request is even better!
Spread the word on Twitter, Facebook, and elsewhere if Jently's been useful to you. The more people who are using the project, the quicker we can find and fix bugs!
