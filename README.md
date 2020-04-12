# subgine-pkg

[![Join the chat at https://gitter.im/gracicot/subgine-pkg](https://badges.gitter.im/gracicot/subgine-pkg.svg)](https://gitter.im/gracicot/subgine-pkg?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

The subgine package manager. A proof of concept package manager we used in our game engine named subgine.

Can resolve dependencies recursively. Does not attempt to solve the diamond problem for the moment.

Here's an example `sbg-manifest.json` file:

```json
{
  "installation-path": "subgine-pkg-modules",
  "dependencies": [
    {
      "name": "kangaru",
      "repository": "https://github.com/gracicot/kangaru.git",
      "options": "-DKANGARU_REVERSE_DESTRUCTION=On",
      "tag": "v4.2.0"
    },
    {
      "name": "cpplocate",
      "repository": "https://github.com/cginternals/cpplocate.git",
      "tag": "v2.1.0",
      "options": "-DOPTION_BUILD_TESTS=Off -DBUILD_SHARED_LIBS=Off",
      "ignore-version": true
    },
    {
      "name": "Catch2",
      "repository": "https://github.com/catchorg/Catch2.git",
      "branch": "master",
      "options": "-DCATCH_BUILD_TESTING=Off -DCATCH_INSTALL_DOCS=Off",
      "version": "v2.9.1"
    }
  ]
}
```

Try it using the [user test sample](https://github.com/gracicot/subgine-pkg-user-test).
