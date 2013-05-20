package MyApp;

use strict;
use warnings;

use Test::More tests => 3;

use Dancer '!pass';
use Dancer::Test;

set appdir => 't';
set views => 't/views';
set template => 'Caribou';
set show_errors => 1;

get '/hi/:name' => sub {
    template 'welcome' => { name => param('name') };
};

response_content_like '/hi/yanick' => qr/hello yanick/;

get '/howdie/:name' => sub {
    template 'howdie' => { name => param('name') };
};

response_content_like '/howdie/yanick' => qr/howdie yanick/;

get '/hullo/:name' => sub {
    
    set layout => 'main';
    template 'hullo' => { name => param('name') };
};

response_content_like '/hullo/yanick' => qr/hullo yanick/;
