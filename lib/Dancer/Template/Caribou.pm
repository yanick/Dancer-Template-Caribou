package Dancer::Template::Caribou;

use strict;
use warnings;

use Path::Tiny;
use Path::Iterator::Rule;
use Moose::Util qw/ with_traits find_meta /;
use FindBin;
use Dancer::Config qw/ setting /;

use Moo;

extends 'Dancer::Template::Abstract';

sub _build_name { 'Dancer::Template::Caribou' };

has 'default_tmpl_ext' => (
    is => 'ro',
    default => sub { 'bou' },
);

has view_class => (
    is => 'ro',
    default => sub { { } },
);

has layout_class => (
    is => 'ro',
    default => sub { { } },
);

has namespace => (
    is => 'ro',
    lazy => 1,
    default => sub {
        $_[0]->config->{namespace} || 'Dancer::View';
    },
);

sub BUILD {
    my $self = shift;

    my $views_dir = setting 'views';

    $DB::single = 1;

    my @views =
    Path::Iterator::Rule->new->skip_dirs('layouts')->file->name('bou')->all(
        $views_dir );

    $self->generate_view_class( $_ ) for @views;

    my @layouts =
    Path::Iterator::Rule->new->file->name('bou')->all(
        path( $views_dir, 'layouts' ) );

    $self->generate_layout_class( $_ ) for @layouts;
}

sub generate_layout_class {
    my( $self, $bou ) = @_;

    my $bou_dir = path($bou)->parent;
    my $segment = ''.path($bou)->relative( setting( 'views').'/layouts')->parent;

    ( my $name = $segment ) =~ s#/#::#;
    $name = join '::', $self->namespace, $name;

    my $inner = path($bou)->slurp;

    eval qq{
package $name;

use Moose::Role;
use Template::Caribou;

with 'Template::Caribou';

with 'Template::Caribou::Files' => {
    dirs => [ '$bou_dir' ],
    auto_reload => 1,
};

# line 1 "$bou"

$inner

1;
} unless find_meta( $name );

    warn $@ if $@;

    $self->layout_class->{$segment} = $name;

}

sub generate_view_class {
    my( $self, $bou ) = @_;

    $DB::single = 1;
    

    my $bou_dir = path($bou)->parent;
    my $segment = ''.path($bou)->relative(setting('views'))->parent;

    ( my $name = $segment ) =~ s#/#::#;
    $name = join '::', $self->namespace, $name;

    return if $self->layout_class->{$segment};

    my $inner = path($bou)->slurp;

    eval qq{
package $name;

use Moose;
use Template::Caribou;

with 'Template::Caribou';

with 'Template::Caribou::Files' => {
    dirs => [ '$bou_dir' ],
    auto_reload => 1,
};

has app => (
    is => 'ro',
    handles => [ 'config' ],
);

# line 1 "$bou"

$inner

1;
} unless find_meta($name);

    warn $@ if $@;

    $self->view_class->{$segment} = $name;

}

sub apply_layout {
    return $_[1];
}

sub layout { 
    return $_[3];
}

sub render {
    my( $self, $template, $tokens ) = @_;

    $template =~ s/\.bou$//;

    $DB::single = 1;

    my $class = $self->view_class->{$template};

    unless ( $class ) {
       my $c = $template;
      $c =~ s#/#::#g;
            $c = join '::', $self->namespace, $c;
          die "template '$template' not found\n"
                unless eval { $c->DOES('Template::Caribou') };
           $class = $c;
      }

    if ( my $lay = Dancer::App->current->setting('layout') ) {
        my $role = $self->layout_class->{$lay}
            or die "layout '$lay' not defined\n";

        $class = with_traits( $class, $role, 
        )
    }

    my $x = $class->new( %$tokens)->render('page');
    use utf8;utf8::decode($x);
    return $x;
}

sub view {
    my( $self, $view ) = @_;
    return $view;
}

sub view_exists {
    1;
}


1;
