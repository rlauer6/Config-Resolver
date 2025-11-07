# NAME

Config::Resolver - Recursively resolve placeholders in a data structure

# SYNOPSIS

    use Config::Resolver;

    # 1. Base use (default, safe functions)
    my $resolver = Config::Resolver->new();
    my $config = $resolver->resolve(
        '${uc(greeting)}', { greeting => 'hello' }
    );
    # $config is now 'HELLO'

    # 2. Extended use (injecting a custom "allowed" function)
    my $resolver_ext = Config::Resolver->new(
        functions => {
            'reverse' => sub { return scalar reverse( $_[0] // '' ) },
        }
    );
    my $config_ext = $resolver_ext->resolve(
        '${reverse(greeting)}', { greeting => 'hello' }
    );
    # $config_ext is now 'olleh'
    
    # 3. Pluggable Backends (for ssm://, vault://, etc.)
    
    # A) Dynamically load installed plugins...

    my $my_plugin_config = {
        'ssm' => { 'endpoint_url' => 'http://localhost:4566' }
    };

    my $resolver_plugins = Config::Resolver->new(
        plugins       => [ 'SSM' ],
        plugin_config => $my_plugin_config,
    );
    
    my $ssm_val = $resolver_plugins->resolve('ssm://my/ssm/path');

    # B) Manual "shim" injection
    my $resolver_manual = Config::Resolver->new(
        backends => {
            'my_db' => sub {
                my ($path, $parameters) = @_;
                # ... logic to resolve $path using $parameters ...
                return "value_for_${path}";
            }
        }
    );

    my $db_val = $resolver_manual->resolve('my_db://foo');
    # $db_val is now 'value_for_foo'

# DESCRIPTION

`Config::Resolver` is a powerful and extensible engine for dynamically
resolving placeholders in complex data structures.

While this module can be used directly in any Perl application
(see [SYNOPSIS](https://metacpan.org/pod/SYNOPSIS)), it is primarily designed as the engine for the
[config-resolver.pl](https://metacpan.org/pod/config-resolver.pl) command-line utility .

The `config-resolver.pl` harness provides a complete, robust, and
testable solution for managing configuration files. It is intended to
replace complex and brittle `sed`, `awk`, or `envsubst` logic
in deployment scripts, such as those found in \`docker-entrypoint.sh\`
scripts or CI/CD pipelines.

This class allows you to define a configuration that contains
placeholders that can be resolved from multiple sources.

- From a hash reference 
- By a safe, "allowed-list" function call 
- By pluggable, protocol-based backends (e.g., `ssm://`) 

# FEATURES

The `Config::Resolver` engine (and its harness) are built to
solve common, real-world DevOps and configuration challenges.

- **Command-Line Harness**

    The primary interface is [config-resolver.pl](https://metacpan.org/pod/config-resolver.pl), a robust,
    feature-complete utility for all configuration tasks. 

- **"Batteries Included" Backends**

    Includes built-in protocol handlers for common use cases,
    such as injecting environment variables (`env://PATH`) and
    file contents (`file://PATH`). See ["Accessing values from Backends (Protocols)"](#accessing-values-from-backends-protocols)
    for details. 

- **Powerful Conditional Logic**

    Replaces complex shell \`if/then\` logic with a safe, built-in
    ternary operator for conditional values. See ["Using the Ternary Operator"](#using-the-ternary-operator)
    for details. 

- **Extensible Plugin Architecture**

    Dynamically fetch secrets from external systems via plugins
    (like the included [Config::Resolver::Plugin::SSM](https://metacpan.org/pod/Config%3A%3AResolver%3A%3APlugin%3A%3ASSM))  or manually
    injected `backends`. See ["PLUGIN API"](#plugin-api) for details. 

- **Safe Function "Allow-List"**

    Perform simple data transformations (e.g., `${uc(hostname)}`)
    using a safe, \`eval\`-free "allow-list" of functions that
    you can extend. See ["Accessing values from a function call"](#accessing-values-from-a-function-call)
    for details. 

- **Robust Batch Processing**

    The [config-resolver.pl](https://metacpan.org/pod/config-resolver.pl) harness supports a powerful `--manifest`
    feature for "Convention Over Configuration" batch processing.

# PLACEHOLDERS

Placeholders in the configuration object can be used to access data
from a hash of provided values, a pluggable backend, or a function
call.

## Accessing values from a hash

You can access values from the `$parameters` hash using a
dot-notation path. The resolver can traverse nested hash references
and array references.

To access a hash key, use its name:

    ${database.host}

To access an array element, use bracket notation with an index:

    ${servers[0].ip}

The path is split by periods, and each part is checked for either a
hash key or an array index.

## Accessing values from a function call

You can perform simple, safe data transformations by wrapping a
parameter path in a function call.

    ${function_name(arg_path)}

The `arg_path` (e.g., `database.host`) is first resolved using
`get_value()`, and its result is then passed as the only argument
to the function.

The `function_name` must exist in the "allow-list" of functions
configured when `Config::Resolver` was instantiated (see the
`functions` option for `new()`). This is a safe, `eval`-free
ispatch.

A base set of functions (`uc`, `lc`) are provided by default.
Example:

    # Resolves 'database.host', then passes it to 'uc'
    ${uc(database.host)}

## Accessing values from Backends (Protocols)

This module supports a "protocol" pattern (`xxx://path`) to resolve
values from external data sources.

### Batteries Included Backends

`Config::Resolver` ships with two "B-U-T-FULL," built-in backends
that are always available:

- **env://PATH**

    Resolves the value from `$ENV{PATH}`. This is the "Merlin" move
    for injecting environment variables.

        # Resolves to the value of the $USER environment variable
        ${env://USER}

- **file://PATH**

    Resolves the value by "slurping" the entire contents of the file
    at `PATH`. This is the "show-stopper" for injecting secrets,
    certificates, or tokens.

        # Slurps the contents of /var/run/secrets/token
        ${file:///var/run/secrets/token}

### Pluggable Backends

You can add \*dynamic\* plugins for services like AWS or Vault.
These are loaded via the `plugins` and `backends`
options in the `new()` constructor.

    # (Assuming the 'SSM' plugin is loaded) ssm://my/parameter/path

## Using the Ternary Operator

The resolver supports a powerful, C-style ternary operator for
simple conditional logic directly within your templates. This is
the "Merlin" move that avoids complex shell scripting and replaces
brittle \`sed\` commands.

The syntax is:

    ${variable_path op "value" ? "true_result" : "false_result"}

- **LHS (Left-Hand Side):** This must be a variable path from
your parameters, like `env` or `database.host`.
- **OP (Operator):** A "B-U-T-FULL" set of safe string (`eq`,
`ne`, `gt`, `lt`, `ge`, `le`) and numeric (`==`, `` != `>` ``,
`<`, `>=`, `<=`) operators are supported.
- **RHS (Right-Hand Side):** This argument is safely parsed
It can be a literal number (`123`), a quoted string (`"prod"` or
`'staging'`), or another variable path (`other.variable`)
- **Results (True/False):** These are also safely parsed
and can be literals, quoted strings, or variable paths.

### Example

Given the parameters:
`{ env => 'prod', db_host => 'prod.db', dev_host => 'dev.db' }`

This template:

    db_host: ${env eq "prod" ? db_host : dev_host}
    db_port: ${env eq "prod" ? 5432 : 1234}

Will resolve to:

    db_host: prod.db
    db_port: 5432

# METHODS AND SUBROUTINES

## new

Creates a new Resolver object. 

    my $resolver = Config::Resolver->new(
        {
            functions       => { 'reverse' => sub { ... } },
            plugins         => [ 'SSM' ],
            backends        => { 'file' => sub { ... } },
            warning_level   => 'warn',
            debug           => $FALSE,
        }
    ); 

Accepts a hash reference with the following keys: 

- functions

    A HASH reference of custom functions to add to the "allow-list"
    for `${...}` function-call placeholders.  (e.g., `${uc(foo)}`)
    These are merged with a base list of safe functions (`uc`, `lc`). 

    Example:

        functions => { 'reverse' => sub { scalar reverse( $_[0] // '' ) } } 

- plugins

    An ARRAY reference of plugin names to auto-load.  For each name
    (e.g., `'SSM'`), the module will attempt to load
    `Config::Resolver::Plugin::SSM`. 

    Loaded plugins register to handle one or more protocols (e.g., `ssm://`). 

- backends

    A HASH reference mapping protocol prefixes to a handler.  This is
    used for manually injecting a "shim" or private handler. 

    The key is the protocol prefix (e.g., `'ssm'`) and the value is a
    subroutine reference or an object that implements a `resolve($path, $parameters)` method. 

    **Note:** Handlers provided here will \*override\* any auto-loaded
    plugins that register the same protocol. 

    Example:

        backends => { 'file' => sub { my ($path, $parameters) = @_; return read_file($path); } } 

- warning\_level

    Indicates whether a warning or error should be generated when
    values cannot be resolved. 

    Valid values: 'warn', 'error' 

    Default: 'error' 

- debug

    Sets debug mode for this class. 

## resolve( $obj, $parameters )

Recursively resolves all placeholders within a given data structure. 
This is the main method you will call after `new()`.

- $obj

    The data structure (scalar, array ref, or hash ref) to resolve.

- $parameters (optional)

    A HASH reference of key/value pairs used to resolve `${...}`
    placeholders. If not provided, the `parameters` passed to
    `new()` will be used.

Returns the resolved data structure.

## finalize\_parameters( $obj, $parameters )

The internal recursive-descent engine. This is called by `resolve()`.
It checks the type of `$obj` and dispatches to `_resolve_array` (for ARRAY refs) .

## resolve\_value( $scalar, $parameters )

Resolves all placeholders within a single scalar value. This method
is the "workhorse" of the resolver and applies resolution in the
following order:

1\. Pluggable Backends (e.g., `ssm://...`) 
2\. Simple Hash Lookups (e.g., `${foo.bar}`) 
3\. Ternary Operators (e.g., `${... ? ...}`) 

Returns the resolved scalar.

## get\_parameter( $parameters, $path\_string )

Retrieves a value from the `$parameters` hash, supporting
dot-notation (`foo.bar`), array-indexing (`foo.bar[0]`), and
safe function calls (`uc(foo.bar)`). 

Function calls are validated against the "allow-list" of functions
provided to `new()`. 

## get\_value( $parameters, $path\_string )

The core path-traversal engine. Given a HASH ref and a
dot-notation path, this method walks the data structure and
returns the value. 

## eval\_arg( $arg\_string, $parameters )

A safe, `eval`-free parser for arguments within a ternary operator. 
It correctly identifies and returns:

1\. Numbers (`123`) 
2\. Quoted Strings (`"foo"` or `'bar'`), with un-escaping. 
3\. Other values, which are assumed to be parameter paths (`foo.bar`) and are resolved. 

# PLUGIN API

This module is extensible via a plugin architecture. A plugin
is a class in the `Config::Resolver::Plugin::*` namespace. 
It must adhere to the following contract:

- **Package Variable: $PROTOCOL**

    The plugin package \*must\* define `our $PROTOCOL = '...'` . This
    variable serves as the \*single, explicit key\* that `Config::Resolver`
    will use to find this plugin's configuration within the
    `plugin_config` hash.

    By convention, this should be the same as the protocol prefix the
    plugin handles (e.g., `'ssm'`).

- new( $options )

    The constructor. It will receive a HASH reference containing \*only\*
    the following keys from the main `Config::Resolver` instance:

    - `debug`
    - `warning_level`
    - (and all keys from its specific config hash)

    For example, if `Config::Resolver-`new()> is called with:
    `plugins => ['SSM'], plugin_config => { ssm => { region => 'us-west-2' } }`

    The `Config::Resolver::Plugin::SSM` \`new()\` method will receive a
    hash reference equivalent to:

        {
          debug         => 0,         # (or 1, if set)
          warning_level => 'error',   # (or 'warn')
          region        => 'us-west-2', # (from the plugin_config)
        }

- init( )

    This method is called after construction. It must return the
    protocol prefix (e.g., `'ssm'`) or an ARRAY ref of protocols
    that this plugin will handle .

- resolve( $path, $parameters )

    The workhorse method. It receives the path string (e.g., `my/key`)
    from the `xxx://my/key` placeholder and the full parameter hash.
    The method must return the resolved value.

# SEE ALSO

[Config::Resolver::Utils](https://metacpan.org/pod/Config%3A%3AResolver%3A%3AUtils)

# AUTHOR

Rob Lauer - <rclauer@gmail.com>

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 865:

    Expected '=item \*'

- Around line 892:

    Expected '=item \*'

- Around line 898:

    Expected '=item \*'
