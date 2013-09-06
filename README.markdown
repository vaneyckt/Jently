[![Travis build status](https://travis-ci.org/vaneyckt/Jently.png?branch=master)](https://travis-ci.org/vaneyckt/Jently)

## Introduction

Jently is a Ruby app that helps you run Jenkins builds on open pull requests on GitHub. 

Jently itself acts as a mediator between Jenkins and GitHub. It talks to GitHub to get an open pull request, creates a testing branch and then instructs Jenkins to run tests on this particular branch. 

After Jenkins has finished testing the branch, Jently collects the result and updates the status of the relevant pull request commit.

### Features

- Jently tests the merged version of a pull request rather than just the feature branch. It takes into account all changes made upstream after a feature branch was created.

- Jently automatically re-runs tests whenever new commits are added to either the pull request itself or the branch that the pull request needs to be merged into.

- Jently uses the [Github Commit Status API](https://github.com/blog/1227-commit-status-api) to update the status of the last commit of a pull request. Whenever possible, a status update contains a link to the Jenkins job that was run to ascertain the correct status.

## Running

There are 4 small steps involved in getting Jently up and running. These steps assume you have a recent version of Ruby installed and have sufficient access to your Jenkins CI so as to add builds.

### Modify your Jenkins CI

You will need to setup a parameterized Jenkins build for testing pull requests. 

Jently will instruct Jenkins to use this build for running tests on an open pull request. You can tell Jently about this build by modifying its configuration file. We will look at this configuration file in a later step, but for now let's focus on setting up the parameterized build.

On the `Configure` build screen of your job, you'll want to check the 'This build is parameterized' checkbox and add a 'branch', 'repository', and 'id' parameter. The order of the parameters is important. It should look like this:

![screenshot](http://imgur.com/5Q3iA.png)

Further down on the Configure build screen you can specify your Source Code Management settings. 

Make sure that your branch specifier is set to `$branch` and that your repository url is set to `$repository`. 

Furthermore, you have to specify the Refspec for pull-requests in "Advanced..." settings:

```
+refs/pull/*:refs/remotes/origin/pr/*
```

It should look like this:

![screenshot](http://imgur.com/LbdKFTY.png)

### Install Jently

Install the gem with: 

``` 
gem install jently
```

### Setup the configuration file

**FIXME: Provide a nice way for people to set this up. Prompt?**

A configuration file can be found in the root of the gem. 

There are a few configuration details that you will need to specify before running Jently. The comments in the file should hopefully make it easy to get everything set up right.

### Run Jently

Jently consists of two programs: 

 - `jently` - Polls GitHub and pokes Jenkins. It runs in the foreground.
 - `jentlyd` - A daemon that wraps `jently`. 

To initially get up and running with Jently, we're going to use the `jently` command and run in the foreground:

```
jently --config path/to/config.yaml
```

By default, `jently` will look for a `config.yaml` file in the current working directory, but here we are overriding this with `--config`.

Jently will start running in the foreground, and output log messages as it does its work. Kill it with ^C. 

Once you are happy with the configuration, start up Jently as a daemon:

```
jentlyd start -- --config path/to/config.yaml
```

`jentlyd` stores state about the `jently` instance it launches in a file called `jentlyd.pid` in the current working directory. You can override this by specifying the `--directory` argument:

```
jentlyd start --directory /var/run/jently -- --config path/to/config.yaml
```

If this is your first run, Jently will start by cloning the specified repository into the /repositories directory, and will also create a .yaml file in the /db directory to help keep track of pull requests.


### Troubleshooting

- Ensure that Jently has read and write permissions for the `/db` folder and its contents.
- Certain older versions of Ruby have been observed to suffer the occasional hiccup. Ruby 2.0.0-p195 will work perfectly.


### Puppet module

There is an example Puppet module in [`dist/`](https://github.com/vaneyckt/Jently/tree/master/dist/puppet-module).

The Puppet module helps you run multiple Jently instances with [Upstart](http://upstart.ubuntu.com/): 

``` puppet
jently::instance { 'project_name':
  github_login      => 'example',
  github_password   => 'hunter2',
  github_repository => 'git@github.com:example/project_name.git',
  jenkins_url       => 'http://jenkins.example.org',
  jenkins_login     => 'example',
  jenkins_password  => 'hunter2',
  jenkins_job_name  => 'example_parameterised_build',
}
```

Create a new `jently::instance` for every project you want to build. 

If you want to run Jently under Upstart (negating the need for `jentlyd`), try adapting the [example configuration](https://github.com/vaneyckt/Jently/blob/master/dist/puppet-module/jently/templates/jently-init.conf.erb).  

## Developing

You'll need to clone the Jently repository to your hard drive in order to get started. Do this by running:

```
git clone git@github.com:vaneyckt/Jently.git
```

Then pull in the dependencies: 

``` 
bundle
```

You're now ready to run the tests:

``` 
bundle exec rake
```

