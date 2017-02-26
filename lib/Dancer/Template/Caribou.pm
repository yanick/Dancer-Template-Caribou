package Dancer::Template::Caribou;
#ABSTRACT: Template::Caribou wrapper for Dancer

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

with 'Template::Caribou::Files' => {
    dirs => [ '$bou_dir' ],
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

    my $bou_dir = path($bou)->parent;
    my $segment = ''.path($bou)->relative(setting('views'))->parent;

    ( my $name = $segment ) =~ s#/#::#;
    $name = join '::', $self->namespace, $name;

    return if $self->layout_class->{$segment};

    my $inner = path($bou)->slurp;

    eval qq{
package $name;

use Template::Caribou;

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

    $DB::single = 1;
    

    $template =~ s/\.bou$//;

    my $class = $self->view_class->{$template};

    unless ( $class ) {
       my $c = $template;
      $c =~ s#/#::#g;
            $c = join '::', $self->namespace, $c;
          die "template '$template' not found\n"
                unless eval { $c->DOES('Template::Caribou::Role') };
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


__END__

=head1 SYNOPSIS

    # in 'config.yml'
    template: Caribou

    engines:
      template:
        Caribou:
          namespace:    MyApp::View
          auto_reload:  1


    # and then in the application
    get '/' => sub { 
        ...;

        template 'main' => \%options;
    };

=head1 DESCRIPTION

C<Dancer::Template::Caribou> is an interface for the L<Template::Caribou>
template system. Be forewarned, both this module and C<Template::Caribou>
itself are alpha-quality software and are still subject to any changes. <Caveat
Maxima Emptor>.

=head2 Basic Usage

At the base, if you do

    get '/' => sub {
        ...

        return template 'MyView', \%options;
    };

the template name (here I<MyView>) will be concatenated with the 
configured view namespace (which defaults to I<Dancer::View>)
to generate the Caribou class name. A Caribou object is created
using C<%options> as its arguments, and its inner template C<page> is then
rendered. In other words, the last line of the code above becomes 
equivalent to 

    return Dancer::View::MyView->new( %options )->render('page');

=head2 '/views' template classes

Template classes can be created straight from the C</views> directory.
Any directory containing a file named C<bou> will be turned into a 
C<Template::Caribou> class. Additionally, any file with a C<.bou> extension
contained within that directory will be turned into a inner template for 
that class.

=head3 The 'bou' file

The 'bou' file holds the custom bits of the Template::Caribou class.

For example, a basic welcome template could be:

    # in /views/welcome/bou
    
    use Template::Caribou::Tags::HTML ':all';

    has name => ( is => 'ro' );

    template page => sub {
        my $self = shift;

        html {
            head { title { 'My App' } };
            body {
                h1 { 'hello ' . $self->name .'!' };
            };
        }
    };

which would be invoqued via

    get '/hi/:name' => sub {
        template 'welcome' => { name => param('name') };
    };


=head3 The inner template files

All files with a '.bou' extension found in the same directory as the 'bou'
file become inner templates for the class. So, to continue with the example
above, we could change it into

    # in /views/howdie/bou
    
    use Template::Caribou::Tags::HTML ':all';

    has name => ( is => 'ro' );


    # in /views/howdie/page
    sub {
        my $self = shift;

        html {
            head { title { 'My App' } };
            body {
                h1 { 'howdie ' . $self->name . '!' };
            };
        }
    }

=head3 Layouts as roles

For the layout sub-directory, an additional piece of magic is performed.
The 'bou'-marked directories are turned into roles instead of classes, which will be applied to
the template class. Again, to take our example:

    # in /views/layouts/main/bou
    # empty file

    # in /views/layouts/main/page
    
    # the import of tags really needs to be here 
    # instead than in the 'bou' file 
    use Template::Caribou::Tags::HTML ':all';

    sub {
        my $self = shift;

        html {
            head { title { 'My App' } };
            body {
                $self->inner_template;
            };
        }
    }

    # in /views/hullo/bou
    
    use Template::Caribou::Tags::HTML ':all';

    has name => ( is => 'ro' );

    # in /views/howdie/inner
    sub { my $self = shift; h1 { 'hullo ' . $self->name . '!' } }


=head1 CONFIGURATION

=over

=item namespace 

The namespace under which the Caribou classes are created.
defaults to C<Dancer::View>.

=back

=cut
