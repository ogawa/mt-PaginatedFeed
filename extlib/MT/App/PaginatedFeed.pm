# PaginatedFeed - Generating feeds with pagination feature.
#
# $Id$
#
# This software is provided as-is. You may use it for commercial or 
# personal use. If you distribute it, please keep this notice intact.
#
# Copyright (c) 2006 Hirotaka Ogawa

package MT::App::PaginatedFeed;
use strict;

use MT::App;
@MT::App::PaginatedFeed::ISA = qw(MT::App);

use MT::Blog;
use MT::Entry;
use MT::Template;
use MT::Template::Context;
use MT::Promise qw(delay);
use HTTP::Date qw(str2time time2str);
use MT::Util qw(ts2epoch);

our $VERSION = '0.01';

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(view => \&view);
    $app->{default_mode} = 'view';
    init_handlers();
    $app;
}

sub view {
    my $app = shift;
    my $q = $app->param;

    my $format = $q->param('format') || 'Atom';
    my $blog_id = $q->param('blog_id')
	or return $app->error($app->translate("No blog_id"));
    my $blog = MT::Blog->load($blog_id)
	or return $app->error($app->translate("Loading blog with ID [_1] failed", $blog_id));

    my $mod_since = $app->get_header('If-Modified-Since');
    if ($mod_since) {
	my ($e) = MT::Entry->load({ blog_id => $blog_id,
				    status => MT::Entry::RELEASE() },
				  { sort => 'modified_on',
				    direction => 'descend',
				    limit => '1' });
	if (ts2epoch($blog, $e->modified_on) <= str2time($mod_since)) {
	    $app->{no_print_body} = 1;
	    $app->response_code(304);
	    $app->response_message('Not Modified');
	    $app->send_http_header("application/xml");
	    return 1;
	}
    }

    my $tmpl = MT::Template->load({ blog_id => $blog_id,
				    name => 'PFeed: ' . $format })
	or return $app->error($app->translate("Can't load '[_1]' template.", "PFeed: $format"));

    my $startIndex = $q->param('startIndex') || 1;
    my $maxResults = $q->param('maxResults') || 20;

    my $ctx = MT::Template::Context->new;
    $ctx->stash('blog', $blog);
    $ctx->stash('blog_id', $blog_id);
    $ctx->stash('PFeed:baseUrl', $q->url);
    $ctx->stash('PFeed:format', $format);
    $ctx->stash('PFeed:startIndex', $startIndex);
    $ctx->stash('PFeed:maxResults', $maxResults);

    my @args = ({ blog_id => $blog_id,
		  status => MT::Entry::RELEASE() },
		{ sort => 'created_on',
		  direction => 'descend',
		  limit => $maxResults,
		  ($startIndex >= 1 ? (offset => $startIndex - 1) : ()) });
    $ctx->stash('entries', delay(sub { my @e = MT::Entry->load(@args); \@e }));

    my $res = $tmpl->build($ctx)
	or return $app->error($app->translate("Building template failed: [_1]", $tmpl->errstr));

    $app->{no_print_body} = 1;
    $app->set_header('Last-Modified', time2str(time));
    $app->send_http_header($ctx->stash('content_type') || 'application/xml');
    $app->print($res);
    1;
}

sub init_handlers {
    my %Handlers = (
	PaginatedFeedStartIndex => \&hdlr_version,
	PaginatedFeedStartIndex => \&hdlr_start_index,
	PaginatedFeedMaxResults => \&hdlr_max_results,
	PaginatedFeedTotalResults => \&hdlr_total_results,
	PaginatedFeedSelfURL => \&hdlr_self_url,
	PaginatedFeedFirstURL => \&hdlr_first_url,
	PaginatedFeedLastURL => \&hdlr_last_url,
	PaginatedFeedNextURL => \&hdlr_next_url,
	PaginatedFeedPreviousURL => \&hdlr_previous_url,
    );
    for my $name (keys %Handlers) {
	MT::Template::Context->add_tag($name, $Handlers{$name});
    }
    MT::Template::Context->add_container_tag('PaginatedFeedEntries', \&hdlr_entries);
}

sub hdlr_version	{ $VERSION }
sub hdlr_start_index	{ $_[0]->stash('PFeed:startIndex') }
sub hdlr_max_results	{ $_[0]->stash('PFeed:maxResults') }

sub hdlr_total_results {
    my ($ctx, $args) = @_;
    my $count = $ctx->stash('PFeed:totalResults');
    return $count if defined $count;
    $count = MT::Entry->count({ blog_id => $ctx->stash('blog')->id,
				status => MT::Entry::RELEASE() });
    $ctx->stash('PFeed:totalResults', $count);
    $count;
}

sub hdlr_self_url	{ _pfeed_url($_[0]) }
sub hdlr_first_url	{ _pfeed_url($_[0], { startIndex => 1 }) }

sub hdlr_last_url {
    my ($ctx, $args) = @_;
    my $count = $ctx->stash('PFeed:totalResults');
    unless (defined $count) {
	$count = MT::Entry->count({ blog_id => $ctx->stash('blog_id'),
				    status => MT::Entry::RELEASE() });
	$ctx->stash('PFeed:totalResults', $count);
    }
    my $startIndex = $ctx->stash('PFeed:startIndex');
    my $maxResults = $ctx->stash('PFeed:maxResults');
    my $index = int(($count - 1) / $maxResults) * $maxResults + 1;
    _pfeed_url($ctx, { startIndex => $index });
}

sub hdlr_next_url {
    my ($ctx, $args) = @_;
    my $count = $ctx->stash('PFeed:totalResults');
    unless (defined $count) {
	$count = MT::Entry->count({ blog_id => $ctx->stash('blog_id'),
				    status => MT::Entry::RELEASE() });
	$ctx->stash('PFeed:totalResults', $count);
    }
    my $startIndex = $ctx->stash('PFeed:startIndex');
    my $maxResults = $ctx->stash('PFeed:maxResults');
    my $index = $startIndex + $maxResults;
    return '' if $count < $index;
    _pfeed_url($ctx, { startIndex => $index });
}

sub hdlr_previous_url {
    my ($ctx, $args) = @_;
    my $startIndex = $ctx->stash('PFeed:startIndex');
    my $maxResults = $ctx->stash('PFeed:maxResults');
    my $index = $startIndex - $maxResults;
    return '' if $index < 1;
    _pfeed_url($ctx, { startIndex => $index });
}

sub _pfeed_url {
    my ($ctx, $args) = @_;
    $ctx->stash('PFeed:baseUrl') .
	'?blog_id=' . ($args->{blog_id} || $ctx->stash('blog_id')) .
	'&format=' . ($args->{format} || $ctx->stash('PFeed:format')) .
	'&startIndex=' . ($args->{startIndex} || $ctx->stash('PFeed:startIndex')) .
	'&maxResults=' . ($args->{maxResults} || $ctx->stash('PFeed:maxResults'));
}

sub hdlr_entries {
    my ($ctx, $args, $cond) = @_;
    my $entries = $ctx->stash('entries');
    my @entries = @$entries;

    my @res;
    my $tokens = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    my($last_day, $next_day) = ('00000000') x 2;
    my $i = 0;
    for my $e (@entries) {
	local $ctx->{__stash}{entry} = $e;
	local $ctx->{current_timestamp} = $e->created_on;
	local $ctx->{modification_timestamp} = $e->modified_on;
	my $this_day = substr $e->created_on, 0, 8;
	my $next_day = $this_day;
	my $footer = 0;
	if (defined $entries[$i+1]) {
	    $next_day = substr($entries[$i+1]->created_on, 0, 8);
	    $footer = $this_day ne $next_day;
	} else {
	    $footer++;
	}
	my $out = $builder->build($ctx, $tokens, {
	    %$cond,
	    DateHeader => ($this_day ne $last_day),
	    DateFooter => $footer,
	    EntriesHeader => !$i,
	    EntriesFooter => !defined $entries[$i+1],
	});
	return $ctx->error($builder->errstr) unless defined $out;
	$last_day = $this_day;
	push @res, $out;
	$i++;
    }
    my $glue = $args->{glue} || '';
    join $glue, @res;
}

1;
