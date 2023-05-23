#!perl

use v5.36;

use Test::More;
use Test::Differences;

use Data::Dumper;

use ok 'ELO::Types', qw[ :core :types ];

=pod

# ...

type *Date => *Str; # FIXME: obviously

type *Amount       => *Int; # assume scaling by 100 for the Float representation
type *CurrencyCode => *Str; # ISO currency codes, tjis could be improced

type *Percentage => *Num; # this should be a constrained number from 1-100

# ...

type *WarehouseId => *Int;
type *ItemId      => *Int;
type *RateId      => *Int;

enum *WarehouseStatus => (
    *WarehouseStatus::OPEN,
    *WarehouseStatus::CLOSED,
);

# ...

# the Rate is something associated with a price in the Inventory type
# it allows the application of a discount

record *Rate => {
    id       => *RateId,
    active   => *Bool,
    discount => *Percentage,
};

# An item is simply something that can be rented

sub record ($symbol, $table) {
    *constructor = sub (%args) {
        bless [ \%args ] => $record_class;
    };
}

sub typeclass ($t, $body) {
    # for Records
    local *method = sub ($name, $body) {
        *{"$record_class::$name"} = sub ($self) {
            $body->( $self->[0] )
        }
    }
}



record *Item => {
    id     => *ItemId,
    active => *Bool,
};

my $item = Item( id => 1, active => 1 );

typeclass[*Item], sub {
    method get_id    => sub ($item) { $item->{id}     };
    method is_active => sub ($item) { $item->{active} };
};

# A warehouse has a status, and an operating currency

record *Warehouse => {
    id       => *WarehouseId,
    status   => *WarehouseStatus,
    currency => *CurrencyCode,
};

# Warehouse Stock at any given moment

table *Stock => [ *WarehouseId, *ItemId ], +{
    count => *Int,
};

# A Price is simply an amount and a currency code

record *Price => {
    amount   => *Amount,
    currency => *CurrencyCode,
};

# Availability is how many can be rented (available), or already are rented (booked)

record *Availability => {
    available => *Int,
    booked    => *Int,
};

# The Inventory is keyed by warehouse, date, $item, and rate
# and will show the price for renting on that day, and the
# current availability of that rental (how many are available vs. booked)

table *Inventory => [ *WarehouseId, *Date, *ItemId, *RateId ], +{
    price        => *Price,
    availability => *Availability,
};

# my $inventory = $global_inventory {$warehouse} {$date} {$item} {$rate};

=cut

done_testing;



