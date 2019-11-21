# nebula-steps [![Build Status](https://travis-ci.com/puppetlabs/nebula-steps.svg?branch=master)](https://travis-ci.com/puppetlabs/nebula-steps)

This is a catalog of Docker images designed to be used with
[Project Nebula](https://puppet.com/project-nebula).

To use one of these step images in your Nebula workflow, see our
[Docker Hub](https://hub.docker.com/u/projectnebula) for the complete list of
available tags.

### Setup for Max OSX users

Build steps require GNU versions of several core utilities. Before running any scripts here, install these with

```
brew install coreutils findutils
```

## Modifying a step image

Most of the images in this repository are simple Bash scripts. To modify the
behavior of the image, simply change `step.sh` as needed. Pull requests welcome!

After updating the `step.sh` content, you can rebuild the image locally by
running `scripts/build <step-name>`. The last line of output contains the name
of the image.

If you need to change the dependencies of the image—for example, to add a new
package—you will need to modify `container.yaml` and regenerate the Dockerfile
by running `scripts/generate`. For more information on the `container.yaml` format, see the [Nebula SDK README](https://github.com/puppetlabs/nebula-sdk/blob/master/README.md#spindle).

You can inject a specification for testing (must be in JSON format with all
secrets and parameters resolved):

```console
$ docker run -e SPEC_URL=file:///spec.json -v /<some-local-dir>/spec.json:/spec.json --rm -ti sdk.nebula.localhost/intermediate/<provided-id>/<step-name>
```

## Creating new step images

To create a new image, you'll need to understand the Spindle `container.yaml`
format. It may be helpful to use one of the existing images in this repository
as a reference.

This repository's convention is that the directory name of a step image is the
same as the image name. Spindle makes this assumption automatically, and the
directory name will be used when tagging the Docker images.

Once you have created a `container.yaml` and any necessary content (for example,
a Go binary or a `step.sh` script), you need to generate the Dockerfile by
running `scripts/generate`. Once the Dockerfile is created, follow the
instructions in the [section on modifying images](#modifying-a-step-image) to
iterate on your step image.

## Examples

The following step images are good examples to use as references when developing
new content:

* [email-sender-smtp](https://github.com/puppetlabs/nebula-steps/tree/master/email-sender-smtp):
  A Go-based step image
* [lambda-function-creator](https://github.com/puppetlabs/nebula-steps/tree/master/lambda-function-creator):
  A Bash script step image with complex dependencies and heavy interaction with
  the `ni` command
* [kaniko](https://github.com/puppetlabs/nebula-steps/tree/master/kaniko): A
  completely custom step image that isn't based on an existing Spindle template
