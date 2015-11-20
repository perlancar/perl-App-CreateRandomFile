package App::CreateRandomFile;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use File::MoreUtil qw(file_exists);
use IO::Prompt::I18N qw(confirm);

our %SPEC;

sub _write_block {
    my ($fh, $block, $size) = @_;
    my $cursize = tell($fh);
    if ($cursize >= $size) {
        return;
    } elsif ($cursize + length($block) > $size) {
        print $fh substr($block, 0, $size - $cursize);
    } else {
        print $fh $block;
    }
}

$SPEC{create_random_file} = {
    v => 1.1,
    summary => 'Create random file',
    description => <<'_',

Create "random" file with a specified size. There are several choices of what
random data to use:

* random bytes, created using `rand()`
* repeated pattern supplied from `--pattern` command-line option

TODO:

* random bytes, source from /dev/urandom
* random lines from a specified file
* random byte sequences from a specified file
_
    args => {
        name => {
            schema => ['str*'],
            req => 1,
            pos => 0,
        },
        size => {
            summary => 'Size (e.g. 10K, 22.5M)',
            schema => ['str*'],
            cmdline_aliases => { s => {} },
            req => 1,
            pos => 1,
        },
        interactive => {
            summary => 'Whether or not the program should be interactive',
            schema => 'bool',
            default => 0,
            description => <<'_',

If set to false then will not prompt interactively and usually will proceed
(unless for dangerous stuffs, in which case will bail immediately.

_
        },
        overwrite => {
            summary => 'Whether to overwrite existing file',
            schema => 'bool',
            default => 0,
            description => <<'_',

If se to true then will overwrite existing file without warning. The default is
to prompt, or bail (if not interactive).

_
        },
        random_bytes => {
            schema => ['bool', is=>1],
        },
        patterns => {
            'x.name.is_plural' => 1,
            schema => ['array*', of=>['str*', min_len=>1], min_len=>1],
        },
    },
    examples => [
        {
            argv => [qw/file1 1M/],
            summary => 'Create a file of size 1MB containing random bytes',
            test => 0,
            'x.doc.show_result' => 0, # so PWP:Rinci doesn't execute our function to get result
        },
        {
            argv => [qw/file2 2M --random-bytes/],
            summary => 'Like the previous example (--random-bytes is optional)',
            test => 0,
            'x.doc.show_result' => 0,
        },
        {
            argv => [qw/file3 3.5K --pattern AABBCC/],
            summary => 'Create a file of size 3.5KB containing repeated pattern',
            test => 0,
            'x.doc.show_result' => 0,
        },
        {
            argv => [qw/file4 4K --pattern A --pattern B --pattern C/],
            summary => 'Create a file of size 4KB containing random sequences of A, B, C',
            test => 0,
            'x.doc.show_result' => 0,
        },
        #{
        #    argv => [qw[file4 4K --random-lines /usr/share/dict/words]],
        #    summary => 'Create a file of size ~4K containing random lines from /usr/share/dict/words',
        #    test => 0,
        #    'x.doc.show_result' => 0,
        #},
    ],
};
sub create_random_file {
    my %args = @_;

    my $interactive = $args{interactive} // 1;

    # TODO: use Parse::Number::WithPrefix::EN
    my $size = $args{size} // 0;
    return [400, "Invalid size, please specify num or num[KMGT]"]
        unless $size =~ /\A(\d+(?:\.\d+)?)(?:([A-Za-z])[Bb]?)?\z/;
    my ($num, $suffix) = ($1, $2);
    if ($suffix) {
        if ($suffix =~ /[Kk]/) {
            $num *= 1024;
        } elsif ($suffix =~ /[Mm]/) {
            $num *= 1024**2;
        } elsif ($suffix =~ /[Gg]/) {
            $num *= 1024**3;
        } elsif ($suffix =~ /[Tt]/) {
            $num *= 1024**4;
        } else {
            return [400, "Unknown number suffix '$suffix'"];
        }
    }
    $num = int($num);

    my $fname = $args{name};

    if (file_exists $fname) {
        if ($interactive) {
            return [200, "Cancelled"]
                unless confirm "Confirm overwrite existing file", {default=>0};
        } else {
            return [409, "File already exists"] unless $args{overwrite};
        }
        unlink $fname or return [400, "Can't unlink $fname: $!"];
    } else {
        if ($interactive) {
            my $s = $suffix ? "$num ($size)" : $num;
            return [200, "Cancelled"]
                unless confirm "Confirm create '$fname' with size $s";
        }
    }

    open my($fh), ">", $fname or return [500, "Can't create $fname: $!"];
    if ($args{patterns}) {
        my $pp = $args{patterns};
        if (@$pp > 1) {
            while (tell($fh) < $num) {
                my $block = "";
                while (length($block) < 4096) {
                    $block .= $pp->[rand @$pp];
                }
                _write_block($fh, $block, $num);
            }
        } else {
            my $block = "";
            while (length($block) < 4096) {
                $block .= $pp->[0];
            }
            while (tell($fh) < $num) {
                _write_block($fh, $block, $num);
            }
        }
    } else {
        while (tell($fh) < $num) {
            my $block = join("", map {chr(rand()*255)} 1..4096);
            _write_block($fh, $block, $num);
        }
    }

    [200, "Done"];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

See L<create-random-file>.

=cut
