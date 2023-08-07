"""Create a repository to hold the toolchains

This follows guidance here:
https://docs.bazel.build/versions/main/skylark/deploying.html#registering-toolchains
"
Note that in order to resolve toolchains in the analysis phase
Bazel needs to analyze all toolchain targets that are registered.
Bazel will not need to analyze all targets referenced by toolchain.toolchain attribute.
If in order to register toolchains you need to perform complex computation in the repository,
consider splitting the repository with toolchain targets
from the repository with <LANG>_toolchain targets.
Former will be always fetched,
and the latter will only be fetched when user actually needs to build <LANG> code.
"
The "complex computation" in our case is simply downloading large artifacts.
This guidance tells us how to avoid that: we put the toolchain targets in the alias repository
with only the toolchain attribute pointing into the platform-specific repositories.
"""

COMPILERS = ["dmd", "ldc"]

# Add more platforms as needed to mirror all the binaries
# published by the upstream project.
PLATFORMS = {
    "x86_64-apple-darwin": struct(
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:x86_64",
        ],
    ),
    "aarch64-apple-darwin": struct(
        compatible_with = [
            "@platforms//os:macos",
            "@platforms//cpu:aarch64",
        ],
    ),
    "x86_64-unknown-linux-gnu": struct(
        compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    ),
    "x86_64-pc-windows-msvc": struct(
        compatible_with = [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
    ),
}

PLATFORM_TO_FILE = {
    "dmd": {
        "x86_64-apple-darwin": "osx.tar.xz",
        "x86_64-unknown-linux-gnu": "linux.tar.xz",
        "x86_64-pc-windows-msvc": "windows.zip",
    },
    "ldc": {
        "x86_64-apple-darwin": "osx-x86_64.tar.xz",
        "aarch64-apple-darwin": "osx-arm64.tar.xz",
        "x86_64-unknown-linux-gnu": "linux-x86_64.tar.xz",
        "x86_64-pc-windows-msvc": "windows-multilib.7z",
    },
}

PLATFORM_TO_NAME = {
    "dmd": {
        "x86_64-apple-darwin": "osx",
        "x86_64-unknown-linux-gnu": "linux",
        "x86_64-pc-windows-msvc": "windows",
    },
    "ldc": {
        "x86_64-apple-darwin": "osx-x86_64",
        "aarch64-apple-darwin": "osx-arm64",
        "x86_64-unknown-linux-gnu": "linux-x86_64",
        "x86_64-pc-windows-msvc": "windows-multilib",
    },
}

def _toolchains_repo_impl(repository_ctx):
    compiler = repository_ctx.attr.compiler

    build_content = """# Generated by toolchains_repo.bzl
#
# These can be registered in the workspace file or passed to --extra_toolchains flag.
# By default all these toolchains are registered by the d_register_toolchains macro
# so you don't normally need to interact with these targets.

"""

    for [platform, meta] in PLATFORMS.items():
        if compiler == "dmd" and platform == "aarch64-apple-darwin":
            continue

        build_content += """
# Declare a toolchain Bazel will select for running the tool in an action
# on the execution platform.
toolchain(
    name = "{compiler}_{platform}_toolchain",
    exec_compatible_with = {compatible_with},
    toolchain = "@{user_repository_name}_{compiler}_{platform}//:d_toolchain",
    toolchain_type = "@gzgz_rules_d//d:toolchain_type",
)
""".format(
            platform = platform,
            name = repository_ctx.attr.name,
            user_repository_name = repository_ctx.attr.user_repository_name,
            compiler = compiler,
            compatible_with = meta.compatible_with + ["@gzgz_rules_d//d/constraints/compiler:%s" % compiler],
        )

    # Base BUILD file for this repository
    repository_ctx.file("BUILD.bazel", build_content)

toolchains_repo = repository_rule(
    _toolchains_repo_impl,
    doc = """Creates a repository with toolchain definitions for all known platforms
     which can be registered or selected.""",
    attrs = {
        "user_repository_name": attr.string(
            doc = "what the user chose for the base name",
        ),
        "compiler": attr.string(
            doc = "the type of compiler to use",
            values = COMPILERS,
        ),
    },
)
