package MarkovChain;
use strict;
use warnings;

use Carp;

=pod

=head1 NAME

MarkovChain - A module using a non-weighted Markov Chain for text manipulation.

=head1 SYNOPSIS

    use MarkovChain;
    my $chain = new MarkovChain($order,$limit);
    $chain->add("some string", @list_of_more_strings);
    print $chain->spew;

=head1 DESCRIPTION

This module creates new sentences from a list of input strings.  After the
module creation, you should seed the generator with one or more sentences.
Calling the spew method will print a new sentence composed of words from
the previous.

=head2 Methods

=over 12

=item C<new>

Returns a new MarkovChain object.

The first parameter to this object sets the "order", or
length of sub-phrases to use for generation.  Higher order
leads to more of the input text being preserved, but
also more coherent output.  Lower is more chaotic.
Defaults to 3.

The second parameter, "limit", sets a maximum length
of the output chain.  When the limit is reached, the sentence
is terminated.  This is primarily used to avoid infinite loops.
Defaults to 50.

=item C<add>

Adds one or more strings to the class.  This has two effects:
the first words of the string are added to the "sentence
beginnings" list.  These are randomly chosen to use later.
Second, the sentence is parsed into phrases.  Each phrase
is stored with a follow-up word, and are used to form the output.

Input strings are somewhat normalized for consistency, by removing
all non-word non-space characters, before usage as lookup keys.
This helps tokens find more possible matches.  Outputs are not
normalized, however, so users may wish to remove problematic characters
such as quotes or parentheses first.

=item C<spew>

Returns a new string, composed randomly from the phrases
currently added to the class.

=back

=head1 LICENSE

This is released under the Artistic 
License. See L<perlartistic>.

=head1 AUTHOR

Greg Kennedy - L<http://greg-kennedy.com/>

=head1 SEE ALSO

L<https://en.wikipedia.org/wiki/Markov_chain#Markov_text_generators>

=cut

# helper: Trim whitespace
sub _trim { my $s = shift; $s =~ s/^\s+//; $s =~ s/\s+$//; $s; }
# helper: Normalize a string
sub _norm { my $s = uc shift; $s =~ s/[^\w ]//; _trim($s); }
# helper: Pick a random list entry.
sub _pick { my @a = keys %{+shift}; $a[int rand @a]; }

# Create new Markov object
sub new
{
  my $class = shift;

  # empty object with defaults
  my %self = (
    order => shift || 3,
    limit => shift || 50,
    chains => {},
    beginnings => {}
  );

  # Die on invalid parameters
  confess "Order is greater than Limit!" if $self{order} > $self{limit};

  # Bless this class and return
  bless \%self, $class;
}

# Tokenize a sentence and add it to the Markov chain hash
sub add
{
  my $self = shift;

  for my $sentence (@_)
  {
    my @words = split /\s+/, _trim($sentence);

    if (@words < $self->{order})
    {
      carp "Cannot use sentence $sentence: too short!";
    } else {
      # Construct sentence beginning
      my $beginning = join ' ', @words[0 .. ($self->{order} - 1)];
      # Normalize
      my $norm_beginning = _norm($beginning);

      if (!exists $self->{beginnings}{$norm_beginning})
      {
        # Beginning does not already exist. Create it.
        $self->{beginnings}{$norm_beginning} = {$beginning => undef};
      } else {
        # Beginning already exists. Add this punct/caps variant.
        $self->{beginnings}{$norm_beginning}{$beginning} = undef;
      }

      # Now iterate through all words, storing prefix and next-word.
      for my $i (0 ..  (@words - $self->{order} - 1))
      {
        my $final_index = $i + $self->{order};

        # construct multi-word prefix
        my $prefix = _norm(join ' ', @words[$i .. ($final_index - 1)]);
        # Retrieve final word
        my $last_word = $words[$final_index];

        # Add to chain.
        if (!exists $self->{chains}{$prefix})
        {
          # Prefix does not already exist. Create it.
          $self->{chains}{$prefix} = {$last_word => undef};
        } else {
          # Prefix already exists.  Put this last word as an endpoint.
          $self->{chains}{$prefix}{$last_word} = undef;
        }
      }
    }
  }
}

# Return the next link in a Markovchain
sub _link
{
  my $self = shift;

  my $prefix = _norm(shift);
  my $depth = shift;

  if ($depth < $self->{limit} && exists $self->{chains}{$prefix})
  {
    # More are available!  Let's pick one at random.
    my $next_word = _pick($self->{chains}{$prefix});

    # Advance prefix and Recurse
    ' ' . $next_word . $self->_link(
      join(' ', (split /\s+/, $prefix)[1 .. ($self->{order} - 1)], $next_word),
      $depth + 1
    );
  } else {
    # Chain ends.
    '';
  }
}

# Return a complete phrase from the chain generator
sub spew
{
  my $self = shift;

  # Pick a random beginning.
  my $prefix = _pick($self->{beginnings}{_pick($self->{beginnings})});

  # Compose a sentence.
  $prefix . $self->_link($prefix,1);
}

1;
