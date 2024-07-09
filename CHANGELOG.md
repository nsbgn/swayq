# Changelog

### 0.1.1 (2024-07-09)

-   **Breaking:** Importing builtin modules must now be done with the 
    `i3jq@` prefix, not the `i3jq/` prefix. Any module with that prefix 
    *must* be a builtin.
-   Builtins can now also be loaded without a prefix, but then modules 
    in the user's configuration take precedence.
-   **Breaking:** Modules in `$ORIGIN/../share/i3jq/` will no longer be 
    found.

## 0.1 (2024-07-06)

First release!
