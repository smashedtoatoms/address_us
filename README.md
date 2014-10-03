AddressUS
=========

**US Address Parser**

This is an Elixir library for parsing US Addresses.  It parses single line
or multi-line addresses and largely ignores punctuation.  It closely follows
the [USPS guidelines](http://pe.usps.com/cpim/ftp/pubs/pub28/pub28.pdf) for address parsing, although it doesn't exactly follow it, particularly in cases where the address is particularly odd.  I hope to update it as I find exceptions.  The easiest way to see the usage is to check out the tests.  The basic rundown is this:

```
iex(1)> parse_address("1500 Serpentine Road Suite 100 Baltimore MD 21"

%Address{city: "Baltimore", postal: "00021", state: "MD", street: %Street{primary_number: "1500", suffix: "Rd", name: "Serpentine", secondary_designator: "Ste", secondary_number: "100"}}
```