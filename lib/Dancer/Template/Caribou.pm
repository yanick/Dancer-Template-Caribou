package Dancer::Template::Caribou;
#ABSTRACT: Template::Caribou wrapper for Dancer

use strict;
use warnings;

use Moose::Util qw/ with_traits find_meta /;
use Dancer::Config qw/ setting /;
use Module::Runtime qw/ use_module /;

use Moo;

extends 'Dancer::Template::Abstract';

sub _build_name { 'Dancer::Template::Caribou' };

has 'default_tmpl_ext' => (
    is => 'ro',
    default => sub { 'bou' },
);

has default_template => (
    is => 'ro',
    lazy => 1,
    default => sub {
        'page'
    },

);

has namespace => (
    is => 'ro',
    lazy => 1,
    predicate => 'has_namespace',
    default => sub {
        $_[0]->config->{namespace} || 'Dancer::View';
    },
);

has layout_namespace => (
    is => 'ro',
    lazy => 1,
    default => sub {
        $_[0]->config->{layout_namespace} 
            or $_[0]->namespace . '::Layout';
    },
);

sub apply_layout {
    return $_[1];
}

sub layout { 
    return $_[3];
}

sub render {
    my( $self, $template, $tokens ) = @_;

    my $class = $template;
    $class = join '::', $self->namespace, $class
        unless $class =~ s/^\+//;

    use_module($class);

    # TODO build a cache of layout + class classes?
    if ( my $layout = Dancer::App->current->setting('layout') ) {
        my $layout_class = $layout;
        $layout_class = join '::', $self->layout_namespace, $layout_class
            unless $layout_class =~ s/^\+//;

        $class = with_traits( $class, use_module($layout_class) );
    }

    my $method = $self->default_template;
    my $x = $class->new( %$tokens)->$method;
    use utf8;utf8::decode($x);
    return $x;
}

sub view {
    my( $self, $view ) = @_;
    return $view;
}

# TODO check if the class exists
sub view_exists {
    1;
}


1;


__END__

=head1 SYNOPSIS

    # in 'config.yml'
    template: Caribou

    engines:
      Caribou:
        namespace:    MyApp::View
        layout_namespace: MyApp::View::Layout
        default_template: page

    # and then in the application
    get '/' => sub { 
        ...;

        template 'main' => \%options;
    };

=head1 DESCRIPTION

C<Dancer::Template::Caribou> is an interface for the L<Template::Caribou>
template system. Be forewarned, both this module and C<Template::Caribou>
itself are alpha-quality software and are still subject to any changes. 
B<Caveat Maxima Emptor>.

=head2 Basic Usage

At the base, if you do

    get '/' => sub {
        ...

        return template 'MyView', \%options;
    };

the template name (here I<MyView>) will be concatenated with the 
configured view namespace (which defaults to I<Dancer::View>)
to generate the Caribou class name. A Caribou object is created
using C<%options> as its arguments, and its default template (defaulting to C<page>) 
is then
rendered. In other words, the last line of the code above becomes 
equivalent to 

    return Dancer::View::MyView->new( %options )->page;

=head3 Layouts as roles

Layouts, just like templates, are package names. They are expected to be
roles that will be composed with the template class.

=head1 CONFIGURATION

=over

=item default_template

The name of the entry template to use. In other words, with the configuration
given in the SYNOPSIS, the dancer code

    return template 'MyThing';

is equivalent to

    return MyApp::View::MyThing->page;

Defaults to C<page>.

=item namespace 

The namespace under which the Caribou template classes are.
defaults to C<Dancer::View>.

=item layout_namespace 

The namespace under which the Caribou layout roles are.
defaults to the C<::Layout> sub-namespace under the template
namespace.

=back

=cut
