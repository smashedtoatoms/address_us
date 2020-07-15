defmodule AddressUSTest do
  use ExUnit.Case

  import AddressUS.Parser, only: [
    parse_address: 1,
    parse_address_line: 1
  ]

  test "Parse 5 digit postal code" do
    desired_result = %Address{postal: "80219"}
    result = parse_address("80219")
    assert desired_result == result
  end

  test "Parse 5 digit postal code with plus4" do
    desired_result = %Address{postal: "80219", plus_4: "1234"}
    result = parse_address("80219-1234")
    assert desired_result == result
  end

  test "Parse 3 digit postal code and pad it with zeros" do
    desired_result = %Address{postal: "00219"}
    result = parse_address("219")
    assert desired_result == result
  end

  test "Parse 4 digit postal code with 2 digit plus4 and pad both with zeros" do
    desired_result = %Address{postal: "00219", plus_4: "0023"}
    result = parse_address("219-23")
    assert desired_result == result
  end

  test "Parse a 6 digit postal code and return a blank field" do
    desired_result = %Address{street: %Street{primary_number: "123456"}}
    result = parse_address("123456")
    assert desired_result == result
  end

  test "Parse postal code and return a blank field" do
    desired_result = %Address{street: %Street{name: "Bob"}}
    result = parse_address("bob")
    assert desired_result == result
  end

  test "Parse address with every type of address field." do
    desired_result = %Address{city: "Denver", plus_4: "1234", postal: "80219",
      state: "CO", street: %Street{name: "B", pmb: "12",
      post_direction: "SW", pre_direction: "S", primary_number: "2345",
      secondary_designator: "Ste", secondary_value: "200", suffix: "St"}}
    result = parse_address("Parse 2345 S. B St. South West, Suite 200
      #12, Denver, Colorado 80219-1234")
    assert desired_result == result
  end

  test "Parse an address with a state abbreviation correctly" do
    desired_result = %Address{city: "Denver", plus_4: "1234", postal: "80219",
      state: "CO", street: %Street{name: "B", pmb: "12",
      post_direction: "SW", pre_direction: "S", primary_number: "2345",
      secondary_designator: "Ste", secondary_value: "200", suffix: "St"}}
    result = parse_address("Parse 2345 S. B St. South West, Suite 200
      #12, Denver, CO 80219-1234")
    assert desired_result == result
  end

  test "Parse an address with an unabbreviated 2-word state" do
    desired_result = %Address{city: "Charlotte", plus_4: "1234",
      postal: "80219", state: "NC", street: %Street{name: "B",
      pmb: "12", post_direction: "SW", pre_direction: "S",
      primary_number: "2345", secondary_designator: "Ste",
      secondary_value: "200", suffix: "St"}}
    result = parse_address("Parse 2345 S. B St. South West, Suite 200
      #12, Charlotte, North Carolina, 80219-1234")
    assert desired_result == result
  end

  test "Parse an address with an unabbreviated 3-word state" do
    desired_result = %Address{city: "Something",
      postal: "80219", state: "DC", street: %Street{name: "Bob",
      primary_number: "2345"}}
    result = parse_address("2345 Bob, Something, District of Columbia
      80219")
    assert desired_result == result
  end

  test "Parse an address with an unabbreviated 4-word state" do
    desired_result = %Address{city: "Something",
      postal: "80219", state: "AE", street: %Street{name: "Bob",
      primary_number: "2345"}}
    result = parse_address("2345 Bob, Something, Armed Forces Middle East
      80219")
    assert desired_result == result
  end

  test "Parse an address with a 2-word city" do
    desired_result = %Address{city: "Bob City",
      postal: "80219", state: "CA", street: %Street{
        name: "Blah", primary_number: "2345", suffix: "St"}}
    result = parse_address("2345 Blah St. Bob City, CA, 80219")
    assert desired_result == result
  end

  test "Parse an address with a business name" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Meade", primary_number: "2345", pre_direction: "SW",
        suffix: "St"}}
    result = parse_address("Bob's Dick Shack 2345 SW Meade St, Denver CO, 80219")
    assert desired_result == result
  end

  test "Parse an address that has an address number that ends with a letter" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Meade", primary_number: "2345", pre_direction: "SW",
        suffix: "St", secondary_value: "B"}}
    result = parse_address("2345B SW Meade St, Denver CO, 80219")
    assert desired_result == result
  end

  test "Parse an address that has a PO Box" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "PO BOX", primary_number: "18"}}
    result = parse_address("PO Box 18, Denver CO, 80219")
    assert desired_result == result
  end

  test "Parse an address that has a PO Box with funny spacing" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "PO BOX", primary_number: "18"}}
    result = parse_address("P. O. Box #18, Denver CO, 80219")
    assert desired_result == result
  end

  test "Parse an address that has a two-word pre_direction" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Blah", primary_number: "2345", pre_direction: "SW",
        suffix: "St"}}
    result = parse_address("2345 South West Blah Street, Denver CO
      80219")
    assert desired_result == result
  end

  test "Parse an address that has a split abbreviated pre_direction" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Blah", primary_number: "2345", pre_direction: "SW",
        suffix: "St"}}
    result = parse_address("2345 S W Blah Street, Denver CO
      80219")
    assert desired_result == result
  end

  test "Parse an address that has a joined two-word pre_direction" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Blah", primary_number: "2345", pre_direction: "SW",
        suffix: "St"}}
    result = parse_address("2345 Southwest Blah Street, Denver CO
      80219")
    assert desired_result == result
  end

  test "Parse an address that has an abbreviated pre_direction" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Blah", primary_number: "2345", pre_direction: "SW",
        suffix: "St"}}
    result = parse_address("2345 SW Blah Street, Denver CO
      80219")
    assert desired_result == result
  end

  test "Parse an address that has an 1/2 abbreviated two-word pre_direction" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Blah", primary_number: "2345", pre_direction: "SW",
        suffix: "St"}}
    result = parse_address("2345 South W Blah Street, Denver CO
      80219")
    assert desired_result == result
  end

  test "Parse an address with a Suite" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Blah", primary_number: "2345", pre_direction: "SW",
        secondary_designator: "Ste", secondary_value: "200", suffix: "St"}}
    result = parse_address("2345 South W Blah Street, Suite 200, Denver
      CO, 80219")
    assert desired_result == result
  end

  test "Parse an address with no secondary number" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Blah", primary_number: "2345", pre_direction: "SW",
        secondary_designator: "Bsmt", suffix: "St"}}
    result = parse_address("2345 South W Blah Street, Basement, Denver
      CO, 80219")
    assert desired_result == result
  end

  test "Parse an address with a secondary number, designator, and pmb" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Blah", primary_number: "2345", pre_direction: "SW",
        secondary_designator: "Ste", secondary_value: "204", suffix: "St",
        pmb: "10"}}
    result = parse_address("2345 South W Blah Street, Suite 204 #10
      Denver CO, 80219")
    assert desired_result == result
  end

  test "Parse an address that has a highway for the street name." do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Highway 80", primary_number: "2345", pre_direction: "SW"}}
    result = parse_address("2345 SW Highway 80, Denver CO 80219")
    assert desired_result == result
  end

  test "Parse an address that has a two-word post_direction" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Blah", primary_number: "2345", post_direction: "SW",
        suffix: "St"}}
    result = parse_address("2345 Blah Street South West, Denver CO
      80219")
    assert desired_result == result
  end

  test "Parse an address that has a split abbreviated post_direction" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Blah", primary_number: "2345", post_direction: "SW",
        suffix: "St"}}
    result = parse_address("2345 Blah Street S W, Denver CO
      80219")
    assert desired_result == result
  end

  test "Parse an address that has a joined two-word post_direction" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Blah", primary_number: "2345", post_direction: "SW",
        suffix: "St"}}
    result = parse_address("2345 Blah Street Southwest, Denver CO
      80219")
    assert desired_result == result
  end

  test "Parse an address that has an abbreviated post_direction" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Blah", primary_number: "2345", post_direction: "SW",
        suffix: "St"}}
    result = parse_address("2345 Blah Street SW, Denver CO
      80219")
    assert desired_result == result
  end

  test "Parse an address that has an 1/2 abbreviated two-word post_direction" do
    desired_result = %Address{city: "Denver",
      postal: "80219", state: "CO", street: %Street{
        name: "Blah", primary_number: "2345", post_direction: "SW",
        suffix: "St"}}
    result = parse_address("2345 Blah Street South W, Denver CO
      80219")
    assert desired_result == result
  end

  test "Parse an address line with every type of address field" do
    desired_result = %Street{name: "B", pmb: "12",
      post_direction: "SW", pre_direction: "S", primary_number: "2345",
      secondary_designator: "Ste", secondary_value: "200", suffix: "St"}
    result = parse_address_line("Parse 2345 S. B St. South West Suite
      200 #12")
    assert desired_result == result
  end

  test "not choke on a garbage address line" do
    desired_result = nil
    result = parse_address_line("")
    assert desired_result == result
  end

  ############################################################################
  ## Random addresses that have broken this library at some point.
  ############################################################################

  test "Parse address: A. P. Croll & Son 2299 Lewes-Georgetown Hwy, Georgetown
      DE 19947-1114" do
    desired_result = %Address{city: "Georgetown", postal: "19947",
      plus_4: "1114", state: "DE", street: %Street{primary_number: "2299",
      suffix: "Hwy", name: "Lewes-Georgetown"}}
    result = parse_address("A. P. Croll & Son 2299 Lewes-Georgetown Hwy
      Georgetown, DE 19947-1114")
    assert desired_result == result
  end

  test "Parse address: 11522 Shawnee Road, Greenwood DE 19950" do
    desired_result = %Address{city: "Greenwood", postal: "19950",
      state: "DE", street: %Street{primary_number: "11522",
      suffix: "Rd", name: "Shawnee"}}
    result = parse_address("11522 Shawnee Road, Greenwood DE 19950")
    assert desired_result == result
  end

  test "Parse address: 144 Kings Highway, S.W. Dover, Delaware 19901" do
    desired_result = %Address{city: "SW Dover", postal: "19901",
      state: "DE", street: %Street{primary_number: "144",
      suffix: "Hwy", name: "Kings"}}
    result = parse_address("144 Kings Highway, S.W. Dover, Delaware 19901")
    assert desired_result == result
  end

  test "Parse address: Intergrated Const. Services 2 Penns Way Suite 405
      New Castle, DE 19720" do
    desired_result = %Address{city: "New Castle", postal: "19720",
      state: "DE", street: %Street{primary_number: "2",
      suffix: "Way", name: "Penns", secondary_designator: "Ste",
      secondary_value: "405"}}
    result = parse_address("Intergrated Const. Services 2 Penns Way Suite 405
      New Castle, DE 19720")
    assert desired_result == result
  end

  test "Parse address: Humes Realty 33 Bridle Ridge Court, Lewes, DE 19958" do
    desired_result = %Address{city: "Lewes", postal: "19958",
      state: "DE", street: %Street{primary_number: "33",
      suffix: "Ct", name: "Bridle Ridge"}}
    result = parse_address("Humes Realty 33 Bridle Ridge Court, Lewes, DE
      19958")
    assert desired_result == result
  end

  test "Parse address: Nichols Excavation 2742 Pulaski Hwy Newark, DE
      19711-8282" do
    desired_result = %Address{city: "Newark", postal: "19711", plus_4: "8282",
      state: "DE", street: %Street{primary_number: "2742", suffix: "Hwy",
      name: "Pulaski"}}
    result = parse_address("Nichols Excavation 2742 Pulaski Hwy Newark, DE
      19711-8282")
    assert desired_result == result
  end

  test "Parse address: 2284 Bryn Zion Road, Smyrna, DE 19904" do
    desired_result = %Address{city: "Smyrna", postal: "19904",
      state: "DE", street: %Street{primary_number: "2284", suffix: "Rd",
      name: "Bryn Zion"}}
    result = parse_address("2284 Bryn Zion Road, Smyrna, DE 19904")
    assert desired_result == result
  end

  test "Parse address: VEI Dover Crossroads, LLC 1500 Serpentine Road
      Suite 100 Baltimore MD 21" do
    desired_result = %Address{city: "Baltimore", postal: "00021",
      state: "MD", street: %Street{primary_number: "1500", suffix: "Rd",
      name: "Serpentine", secondary_designator: "Ste", secondary_value: "100"}}
    result = parse_address("VEI Dover Crossroads, LLC 1500 Serpentine Road
      Suite 100 Baltimore MD 21")
    assert desired_result == result
  end

  test "Parse address: 580 North Dupont Highway Dover, DE 19901" do
    desired_result = %Address{city: "Dover", postal: "19901",
      state: "DE", street: %Street{primary_number: "580", suffix: "Hwy",
      name: "Dupont", pre_direction: "N"}}
    result = parse_address("580 North Dupont Highway Dover, DE 19901")
    assert desired_result == result
  end

  test "Parse address: P.O. Box 778 Dover, DE 19903" do
    desired_result = %Address{city: "Dover", postal: "19903",
      state: "DE", street: %Street{primary_number: "778",
      name: "PO BOX"}}
    result = parse_address("P.O. Box 778 Dover, DE 19903")
    assert desired_result == result
  end

  test "Parse address: State Rd 2 & Carr #128, Yauco, PR" do
    desired_result = %Address{city: "Yauco",
      state: "PR", street: %Street{name: "Carr", pmb: "128"}}
    result = parse_address("State Rd 2 & Carr #128, Yauco, PR")
    assert desired_result == result
  end

  test "Parse address: Rr 2 Box 631, Bridgeport, WV" do
    desired_result = %Address{city: "Bridgeport",
      state: "WV", street: %Street{name: "PO BOX", primary_number: "631"}}
    result = parse_address("Rr 2 Box 631, Bridgeport, WV")
    assert desired_result == result
  end

  test "Parse address: 2155 SR-18, Brandon, MS" do
    desired_result = %Address{city: "Brandon", state: "MS",
      street: %Street{name: "State Route 18", primary_number: "2155"}}
    result = parse_address("2155 SR-18, Brandon, MS")
    assert desired_result == result
  end

  test "Parse address: 804 & 806 W Street, Watertown, North Dakota" do
    desired_result = %Address{city: "Watertown", state: "ND",
      street: %Street{name: "West", primary_number: "806", suffix: "St"}}
    result = parse_address("804 & 806 W Street, Watertown, North Dakota")
    assert desired_result == result
  end

  test "Parse address: 804 & 806 N West Street, Watertown, WI" do
    desired_result = %Address{city: "Watertown", state: "WI",
      street: %Street{name: "West", pre_direction: "N", primary_number: "806",
      suffix: "St"}}
    result = parse_address("804 & 806 N West Street, Watertown, WI")
    assert desired_result == result
  end

  test "Parse address: 804 & 806 1/2 North West Street, Bizarro, WI" do
    desired_result = %Address{city: "Bizarro", state: "WI",
      street: %Street{name: "West", pre_direction: "N",
      primary_number: "806 1/2", suffix: "St"}}
    result = parse_address("804 & 806 1/2 North West Street, Bizarro, WI")
    assert desired_result == result
  end

  test "Parse address: 804 & 806 1/2 North West West Street, Suite 11 #22
      Bizarro, WI" do
    desired_result = %Address{city: "Bizarro", state: "WI",
      street: %Street{name: "West", pre_direction: "NW",
      primary_number: "806 1/2", suffix: "St", secondary_designator: "Ste",
      secondary_value: "11", pmb: "22"}}
    result = parse_address("804 & 806 1/2 North West West Street, Suite 11 #22
      Bizarro, WI")
    assert desired_result == result
  end

  test "Parse address: 2345 Highway 3 Bypass Road, Suite 22 #65, Casper, WY
      82609" do
    desired_result = %Address{city: "Casper", state: "WY", postal: "82609",
      street: %Street{name: "Highway 3 Bypass", suffix: "Rd",
      primary_number: "2345", secondary_designator: "Ste", pmb: "65",
      secondary_value: "22"}}
    result = parse_address("2345 Highway 3 Bypass Road, Suite 22 #65, Casper
      WY 82609")
    assert desired_result == result
  end

  test "Parse address: 5567 IH-280, Suite 22 #65, Casper, WY, 82609" do
    desired_result = %Address{city: "Casper", state: "WY", postal: "82609",
      street: %Street{name: "Interstate 280", primary_number: "5567",
      secondary_designator: "Ste", pmb: "65", secondary_value: "22"}}
    result = parse_address("5567 IH-280, Suite 22 #65, Casper, WY, 82609")
    assert desired_result == result
  end

  test "Parse address: 5567 I-55 Bypass Road, Suite 22 #65, Casper, WY" do
    desired_result = %Address{city: "Casper", state: "WY",
      street: %Street{name: "Interstate 55 Bypass", primary_number: "5567",
      secondary_designator: "Ste", pmb: "65", secondary_value: "22",
      suffix: "Rd"}}
    result = parse_address("5567 I-55 Bypass Road, Suite 22 #65, Casper, WY")
    assert desired_result == result
  end

  test "Parse address: 2345 Highway 26 Frontage Road, Suite 22 #65, Casper
      WY, 82609" do
    desired_result = %Address{city: "Casper", state: "WY", postal: "82609",
      street: %Street{name: "Highway 26 Frontage", primary_number: "2345",
      secondary_designator: "Ste", pmb: "65", secondary_value: "22",
      suffix: "Rd"}}
    result = parse_address("2345 Highway 26 Frontage Road, Suite 22 #65
      Casper, WY, 82609")
    assert desired_result == result
  end

  test "Parse address: 2345 US Highway 44 SW, Suite 22, Casper, WY, 82609" do
    desired_result = %Address{city: "Casper", state: "WY", postal: "82609",
      street: %Street{name: "US Highway 44", primary_number: "2345",
      post_direction: "SW", secondary_designator: "Ste",
      secondary_value: "22"}}
    result = parse_address("2345 US Highway 44 SW, Suite 22, Casper, WY, 82609")
    assert desired_result == result
  end

  test "Parse address: 14 County Road North East, Suite 22, Casper, WY
      82609" do
    desired_result = %Address{city: "Casper", state: "WY", postal: "82609",
      street: %Street{name: "County", primary_number: "14",
      post_direction: "NE", secondary_designator: "Ste",
      secondary_value: "22", suffix: "Rd"}}
    result = parse_address("14 County Road North East, Suite 22, Casper, WY
      82609")
    assert desired_result == result
  end

  test "Parse address: Georgia 138 Riverdale, GA 30274" do
    desired_result = %Address{city: "Riverdale", state: "GA", postal: "30274",
      street: %Street{name: "Georgia 138"}}
    result = parse_address("Georgia 138 Riverdale, GA 30274")
    assert desired_result == result
  end

  test "Parse address: 2230 Farm to Market 407, Highland Village, TX 75077" do
    desired_result = %Address{city: "Highland Village", state: "TX",
    postal: "75077", street: %Street{name: "Farm To Market 407",
    primary_number: "2230"}}
    result = parse_address("2230 Farm to Market 407, Highland Village, TX
      75077")
    assert desired_result == result
  end

  test "Parse address: 1700 Box Rd, Columbus, GA 75077" do
    desired_result = %Address{city: "Columbus", state: "GA",
    postal: "75077", street: %Street{name: "Box", suffix: "Rd",
    primary_number: "1700"}}
    result = parse_address("1700 Box Rd, Columbus, GA 75077")
    assert desired_result == result
  end

  test "Parse address: 3300 Bee Caves Rd Unit 670, Austin TX 78747" do
    desired_result = %Address{city: "Austin", state: "TX",
    postal: "78747", street: %Street{name: "Bee Caves", suffix: "Rd",
    primary_number: "3300", secondary_designator: "Unit",
    secondary_value: "670"}}
    result = parse_address("3300 Bee Caves Rd Unit 670, Austin TX 78747")
    assert desired_result == result
  end

  test "Parse address: 4423 E Thomas Rd Ste B Phoenix, AZ 85018" do
    desired_result = %Address{city: "Phoenix", state: "AZ",
    postal: "85018", street: %Street{name: "Thomas", suffix: "Rd",
    primary_number: "4423", pre_direction: "E", secondary_designator: "Ste",
    secondary_value: "B"}}
    result = parse_address("4423 E Thomas Rd Ste B Phoenix, AZ 85018")
    assert desired_result == result
  end

  test "Parse address: 4423 E Thomas Rd (SEC) Ste B Phoenix, AZ 85018" do
    desired_result = %Address{city: "Phoenix", state: "AZ",
    postal: "85018", street: %Street{name: "Thomas", suffix: "Rd",
    primary_number: "4423", pre_direction: "E", secondary_designator: "Ste",
    secondary_value: "B"}}
    result = parse_address("4423 E Thomas Rd (SEC) Ste B Phoenix, AZ 85018")
    assert desired_result == result
  end

  test "Parse address: 4423 E Thomas Rd (Ste B) Phoenix, AZ 85018" do
    desired_result = %Address{city: "Phoenix", state: "AZ",
    postal: "85018", street: %Street{name: "Thomas", suffix: "Rd",
    primary_number: "4423", pre_direction: "E", secondary_designator: "Ste",
    secondary_value: "B"}}
    result = parse_address("4423 E Thomas Rd (Ste B) Phoenix, AZ 85018")
    assert desired_result == result
  end

  test "Parse address: 11681 US HWY 70, Clayton, NC 27520" do
    desired_result = %Address{city: "Clayton", state: "NC",
    postal: "27520", street: %Street{name: "US Hwy 70",
    primary_number: "11681"}}
    result = parse_address("11681 US HWY 70, Clayton, NC 27520")
    assert desired_result == result
  end

  test "Parse address: 435 N 1680 East Suite # 8, St. George, UT 8470" do
    desired_result = %Address{city: "St George", state: "UT",
    postal: "08470", street: %Street{name: "1680",
    primary_number: "435", pre_direction: "N", post_direction: "E",
    secondary_designator: "Ste",secondary_value: "8"}}
    result = parse_address("435 N 1680 East Suite # 8, St. George, UT 8470")
    assert desired_result == result
  end

  test "Parse address: 5 Bel Air S Parkway Suite L 1219, Bel Air, MD, 21015" do
    desired_result = %Address{city: "Bel Air", state: "MD",
    postal: "21015", street: %Street{name: "Bel Air S",
    primary_number: "5", suffix: "Pkwy",
    secondary_designator: "Ste",secondary_value: "L1219"}}
    result = parse_address("5 Bel Air S Parkway Suite L 1219, Bel Air, MD, 21015")
    assert desired_result == result
  end

  test "Parse address: 140 W Hively Avenue STE 2, Bel Air, MD, 21015" do
    desired_result = %Address{city: "Bel Air", state: "MD",
    postal: "21015", street: %Street{name: "Hively",
    primary_number: "140", pre_direction: "W", suffix: "Ave",
    secondary_designator: "Ste", secondary_value: "2"}}
    result = parse_address("140 W Hively Avenue STE 2, Bel Air, MD, 21015")
    assert desired_result == result
  end

  test "Parse address: 2242 W 5400 S, Salt Lake City, UT 75169" do
    desired_result = %Address{city: "Salt Lake City", state: "UT",
    postal: "75169", street: %Street{name: "5400",primary_number: "2242",
    pre_direction: "W", post_direction: "S"}}
    result = parse_address("2242 W 5400 S, Salt Lake City, UT 75169")
    assert desired_result == result
  end

  test "Parse address: 2242 W 5400 S, West Valley City, UT 75169" do
    desired_result = %Address{city: "West Valley City", state: "UT",
    postal: "75169", street: %Street{name: "5400",primary_number: "2242",
    pre_direction: "W", post_direction: "S"}}
    result = parse_address("2242 W 5400 S, West Valley City, UT 75169")
    assert desired_result == result
  end

  test "Parse address: 227 Fox Hill Rd Unit C-3, Orlando, FL 32803" do
    desired_result = %Address{city: "Orlando", state: "FL",
    postal: "32803", street: %Street{name: "Fox Hill",primary_number: "227",
    secondary_designator: "Unit", secondary_value: "C-3", suffix: "Rd"}}
    result = parse_address("227 Fox Hill Rd Unit C-3, Orlando, FL 32803")
    assert desired_result == result
  end

  test "Parse address: 227 Fox Hill Rd Unit#7, Orlando, FL 32803" do
    desired_result = %Address{city: "Orlando", state: "FL",
    postal: "32803", street: %Street{name: "Fox Hill",primary_number: "227",
    secondary_designator: "Unit", secondary_value: "7", suffix: "Rd"}}
    result = parse_address("227 Fox Hill Rd Unit#7, Orlando, FL 32803")
    assert desired_result == result
  end

  test "Parse address: 227A Fox Hill Rd, Orlando, FL 32803" do
    desired_result = %Address{city: "Orlando", state: "FL",
    postal: "32803", street: %Street{name: "Fox Hill",primary_number: "227",
    secondary_value: "A", suffix: "Rd"}}
    result = parse_address("227A Fox Hill Rd, Orlando, FL 32803")
    assert desired_result == result
  end

  test "233-B South Country Drive, Waverly, VA 32803" do
    desired_result = %Address{city: "Waverly", state: "VA",
    postal: "32803", street: %Street{name: "Country",primary_number: "233",
    secondary_value: "B", pre_direction: "S", suffix: "Dr"}}
    result = parse_address("233-B South Country Drive, Waverly, VA 32803")
    assert desired_result == result
  end

  test "820 A South Country Drive, Waverly, VA 32803" do
    desired_result = %Address{city: "Waverly", state: "VA",
    postal: "32803", street: %Street{name: "Country",primary_number: "820",
    secondary_value: "A", pre_direction: "S", suffix: "Dr"}}
    result = parse_address("820 A South Country Drive, Waverly, VA 32803")
    assert desired_result == result
  end

  # test "15 North Main St C03, Waverly, VA 32803" do
  #   desired_result = %Address{city: "Waverly", state: "VA",
  #   postal: "32803", street: %Street{name: "Main",primary_number: "15",
  #   secondary_value: "C03", pre_direction: "N", suffix: "St"}}
  #   result = parse_address("15 North Main St C03, Waverly, VA 32803")
  #   assert desired_result == result
  # end

  test "820 A E. Admiral Doyle Dr, Waverly, VA 32803" do
    desired_result = %Address{city: "Waverly", state: "VA",
    postal: "32803", street: %Street{name: "Admiral Doyle",
    primary_number: "820", secondary_value: "A", pre_direction: "E",
    suffix: "Dr"}}
    result = parse_address("820 A E. Admiral Doyle Dr, Waverly, VA 32803")
    assert desired_result == result
  end

  test "820 a E. Admiral Doyle Dr, Waverly, VA 32803" do
    desired_result = %Address{city: "Waverly", state: "VA",
    postal: "32803", street: %Street{name: "Admiral Doyle",
    primary_number: "820", secondary_value: "A", pre_direction: "E",
    suffix: "Dr"}}
    result = parse_address("820 a E. Admiral Doyle Dr, Waverly, VA 32803")
    assert desired_result == result
  end

  test "394 S. HWY 29, Cantonment, FL 32803" do
    desired_result = %Address{city: "Cantonment", state: "FL",
    postal: "32803", street: %Street{name: "Hwy 29",
    primary_number: "394", pre_direction: "S"}}
    result = parse_address("394 S. HWY 29, Cantonment, FL 32803")
    assert desired_result == result
  end

  test "5810 Bellfort St Ste D & E, Cantonment, FL 32803" do
    desired_result = %Address{city: "Cantonment", state: "FL",
    postal: "32803", street: %Street{name: "Bellfort",
    primary_number: "5810", secondary_designator: "Ste", secondary_value: "D",
    suffix: "St"}}
    result = parse_address("5810 Bellfort St Ste D & E, Cantonment, FL 32803")
    assert desired_result == result
  end

  # test "5000-16 Norwood Avenue, Space A-16, Jacksonville, FL 32208" do
  #   desired_result = %Address{city: "Jacksonville", state: "FL",
  #   postal: "32208", street: %Street{name: "Norwood", primary_number: "5000",
  #   secondary_designator: "Spc", secondary_value: "A-16", suffix: "Ave"}}
  #   result = parse_address("5000-16 Norwood Avenue, Space A-16, Jacksonville, FL 32208")
  #   assert desired_result == result
  # end

  # test "605-13 New Market Dr. Newport News, VA 23605" do
  #   desired_result = %Address{city: "Newport News", state: "VA",
  #   postal: "23605", street: %Street{name: "New Market", primary_number: "605",
  #   secondary_value: "13", suffix: "Dr"}}
  #   result = parse_address("605-13 New Market Dr. Newport News, VA 23605")
  #   assert desired_result == result
  # end

  # test "21-41 Main Street, Lockport, NY 14094" do
  #   desired_result = %Address{city: "Lockport", state: "NY",
  #   postal: "14094", street: %Street{name: "Main", primary_number: "21",
  #   secondary_value: "41", suffix: "St"}}
  #   result = parse_address("21-41 Main Street, Lockport, NY 14094")
  #   assert desired_result == result
  # end

  # test "18115 Highway I-30, Benton, AZ, 72015" do
  #   desired_result = %Address{city: "Benton", state: "AZ",
  #   postal: "72015", street: %Street{name: "I-30", primary_number: "18115"}}
  #   result = parse_address("18115 Highway I-30, Benton, AZ, 72015")
  #   assert desired_result == result
  # end

  # test "230 E. State Route 89A, Cottonwood, AZ, 86326" do
  #   desired_result = %Address{city: "Cottonwood", state: "AZ",
  #   postal: "86326", street: %Street{name: "State Route 89A",
  #   primary_number: "230", pre_direction: "E"}}
  #   result = parse_address("230 E. State Route 89A, Cottonwood, AZ, 86326")
  #   assert desired_result == result
  # end

  test "5227 14th St W, Bradenton, FL, 34207" do
    desired_result = %Address{city: "Bradenton", state: "FL",
    postal: "34207", street: %Street{name: "14th",
    primary_number: "5227", post_direction: "W" ,
    suffix: "St"}}
    result = parse_address("5227 14th St W, Bradenton, FL, 34207")
    assert desired_result == result
  end

  test "1429 San Mateo Blvd NE, Albuquerque, NM, 87110" do
    desired_result = %Address{city: "Albuquerque", state: "NM",
    postal: "87110", street: %Street{name: "San Mateo",
    primary_number: "1429", post_direction: "NE" ,
    suffix: "Blvd"}}
    result = parse_address("1429 San Mateo Blvd NE, Albuquerque, NM, 87110")
    assert desired_result == result
  end

  test "10424 Campus Way South, Upper Marlboro, MD, 20774" do
    desired_result = %Address{city: "Upper Marlboro", state: "MD",
    postal: "20774", street: %Street{name: "Campus",
    primary_number: "10424", post_direction: "S" ,
    suffix: "Way"}}
    result = parse_address("10424 Campus Way South, Upper Marlboro, MD, 20774")
    assert desired_result == result
  end

  test "3101 PGA Blvd, Palm Beach Gardens, FL 33401" do
    desired_result = %Address{city: "Palm Beach Gardens", state: "FL",
    postal: "33401", street: %Street{name: "PGA",
    primary_number: "3101", suffix: "Blvd"}}
    result = parse_address("3101 PGA Blvd, Palm Beach Gardens, FL 33401")
    assert desired_result == result
  end

  test "2341 Rt 66, Ocean, NJ 7712" do
    desired_result = %Address{city: "Ocean", state: "NJ",
    postal: "07712", street: %Street{name: "Route 66",
    primary_number: "2341"}}
    result = parse_address("2341 Rt 66, Ocean, NJ 7712")
    assert desired_result == result
  end

  test "2407 M L King Ave, Flint, MI 48505" do
    desired_result = %Address{city: "Flint", state: "MI",
    postal: "48505", street: %Street{name: "Martin Luther King",
    primary_number: "2407", suffix: "Ave"}}
    result = parse_address("2407 M L King Ave, Flint, MI 48505")
    assert desired_result == result
  end

  # test "3590 W. South Jordan Pkwy, South Jordan, UT 84095" do
  #   desired_result = %Address{city: "South Jordan", state: "UT",
  #   postal: "84095", street: %Street{name: "South Jordan",
  #   primary_number: "3590", pre_direction: "W", suffix: "Pkwy"}}
  #   result = parse_address("3590 W. South Jordan Pkwy, South Jordan, UT 84095")
  #   assert desired_result == result
  # end

  # test "5th Street, Suite 100, Denver, CO 80219" do
  #   desired_result = %Address{city: "Denver", state: "CO",
  #   postal: "80219", street: %Street{name: "5th", suffix: "St"}}
  #   result = parse_address("5th Street, Suite 100, Denver, CO 80219")
  #   assert desired_result == result
  # end

  # test "1315 U.S. 80 E, Demopolis, AL 36732, United States" do
  #   desired_result = %Address{city: "Demopolis", state: "AL",
  #   postal: "36732", street: %Street{name: "US 80",
  #   primary_number: "1315", post_direction: "E"}}
  #   result = parse_address("1315 U.S. 80 E, Demopolis, AL 36732, United States")
  #   assert desired_result == result
  # end

  test "2345 Front Street, Denver, CO 80219" do
    desired_result = %Address{city: "Denver", state: "CO",
    postal: "80219", street: %Street{name: "Front",
    primary_number: "2345", suffix: "St"}}
    result = parse_address("2345 Front Street, Denver, CO 80219")
    assert desired_result == result
  end

  # test "5215 W Indian School Rd, Ste 103 & 104, Phoenix, AZ 85031" do
  #   desired_result = %Address{city: "Phoenix", state: "AZ",
  #   postal: "85031", street: %Street{name: "Indian School",
  #   primary_number: "5215", suffix: "Rd", pre_direction: "W",
  #   secondary_designator: "Ste", secondary_value: "103"}}
  #   result = parse_address("5215 W Indian School Rd, Ste 103 & 104, Phoenix, AZ 85031")
  #   assert desired_result == result
  # end

  test "1093 B St, Hayward, CA, 94541" do
    desired_result = %Address{city: "Hayward", state: "CA",
    postal: "94541", street: %Street{name: "B",
    primary_number: "1093", suffix: "St"}}
    result = parse_address("1093 B St, Hayward, CA, 94541")
    assert desired_result == result
  end

  test "937 Pearline Plaza, New Ike, MO, 00053" do
    desired_result = %Address{city: "New Ike", state: "MO",
    postal: "00053", street: %Street{name: "Pearline",
    primary_number: "937", suffix: "Plz"}}
    result = parse_address("937 Pearline Plaza, New Ike, MO, 00053")
    assert desired_result == result
  end
end
