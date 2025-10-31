#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Data::Dumper;
use English qw(-no_match_vars);
use Config::Resolver;
use Readonly;
use Scalar::Util qw(reftype);

Readonly::Scalar our $TRUE  => 1;
Readonly::Scalar our $FALSE => 0;

use_ok 'Config::Resolver';

########################################################################
subtest '1. Plugin loading' => sub {
########################################################################
  SKIP: {
    skip 'no ssm', 2 if !$ENV{TEST_SSM};

    my $resolver = Config::Resolver->new( debug => 0, plugins => ['SSM'] );

    my $handlers = $resolver->get_handler_map;
    ok( $handlers->{ssm}, 'Handler map has "ssm" key' );
    isa_ok( $handlers->{ssm}, 'Config::Resolver::Plugin::SSM' );
  }

};

########################################################################
subtest '2. Plugin resolution (SSM)' => sub {
########################################################################
  SKIP: {
    skip 'no ssm', 1 if !$ENV{TEST_SSM};
    # This test relies on a live AWS (or LocalStack) connection
    # It's effectively the same as your old 01-config.t SSM test
    my $resolver = Config::Resolver->new( debug => 0, plugins => ['SSM'] );

    my $ref = $resolver->resolve( { foo => 'ssm://rds/mysql/host' } );
    is( $ref->{foo}, 'treasurersbriefcase-sandbox.cmjzu8mkvkk3.us-east-1.rds.amazonaws.com' );
  }

};

########################################################################
subtest '3. Manual "backend" injection' => sub {
########################################################################
  # This tests the manual "backends" hash
  my $resolver = Config::Resolver->new(
    backends => {
      'test' => sub {
        # THIS IS THE NEW PART: We USE the $parameters hash
        my ( $path, $parameters ) = @_;
        return "path was: $path, env was: " . $parameters->{env};
      }
    }
  );

  # We pass parameters in the resolve() call
  my $result = $resolver->resolve( 'test://foo/bar', { env => 'dev' } );

  # The test now confirms the $parameters hash was received
  is( $result, 'path was: foo/bar, env was: dev', 'Manual backend coderef works and receives parameters' );
};

########################################################################
subtest '4. Manual "backend" OVERRIDES auto-plugin' => sub {
########################################################################
  # This proves that "backends" wins over "plugins"
  SKIP: {
    skip 'no ssm', 2 if !$ENV{TEST_SSM};

    my $resolver = Config::Resolver->new(
      plugins  => ['SSM'],  # Tries to load SSM
      backends => {
        'ssm' => sub { return 'OVERRIDDEN' }  # But we override it
      }
    );

    my $handlers = $resolver->get_handler_map;
    is( reftype( $handlers->{ssm} ), 'CODE', 'Handler for "ssm" is a coderef, not object' );

    my $result = $resolver->resolve('ssm://any/path');
    is( $result, 'OVERRIDDEN', 'Manual backend correctly overrides plugin' );
  }

};

########################################################################
subtest '5. Plugin loading (Non-existent plugin)' => sub {
########################################################################
  # This tests our 'load $class' error handling
  my $result = eval { my $resolver = Config::Resolver->new( plugins => ['ThisPluginDoesNotExist'] ); };

  ok( !$result && $EVAL_ERROR, 'Resolver croaks on non-existent plugin' );
  like(
    $EVAL_ERROR,
    qr/Can't locate Config\/Resolver\/Plugin\/ThisPluginDoesNotExist.pm/,
    'Error message is from Module::Load'
  );
};

done_testing;

1;
