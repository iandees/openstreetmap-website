require File.dirname(__FILE__) + '/../test_helper'

class WayTest < ActiveSupport::TestCase
  api_fixtures

  # Check that we have the correct number of currnet ways in the db
  # This will need to updated whenever the current_ways.yml is updated
  def test_db_count
    assert_equal 6, Way.count
  end
  
  def test_bbox
    node = current_nodes(:used_node_1)
    [ :visible_way,
      :invisible_way,
      :used_way ].each do |way_symbol|
      way = current_ways(way_symbol)
      assert_equal node.bbox.min_lon, way.bbox.min_lon, 'min_lon'
      assert_equal node.bbox.min_lat, way.bbox.min_lat, 'min_lat'
      assert_equal node.bbox.max_lon, way.bbox.max_lon, 'max_lon'
      assert_equal node.bbox.max_lat, way.bbox.max_lat, 'max_lat'
    end
  end
  
  # Check that the preconditions fail when you are over the defined limit of 
  # the maximum number of nodes in each way.
  def test_max_nodes_per_way_limit
    # Take one of the current ways and add nodes to it until we are near the limit
    way = Way.find(current_ways(:visible_way).id)
    assert way.valid?
    # it already has 1 node
    1.upto((MAX_NUMBER_OF_WAY_NODES) / 2) {
      way.add_nd_num(current_nodes(:used_node_1).id)
      way.add_nd_num(current_nodes(:used_node_2).id)
    }
    way.save
    #print way.nds.size
    assert way.valid?
    way.add_nd_num(current_nodes(:visible_node).id)
    assert way.valid?
  end
  
  def test_from_xml_no_id
    noid = "<osm><way version='12' changeset='23' /></osm>"
    check_error_attr_new_ok(noid, Mime::XML, /ID is required when updating/)
  end
  
  def test_from_xml_no_changeset_id
    nocs = "<osm><way id='123' version='23' /></osm>"
    check_error_attr(nocs, Mime::XML, /Changeset id is missing/)
  end
  
  def test_from_xml_no_version
    no_version = "<osm><way id='123' changeset='23' /></osm>"
    check_error_attr_new_ok(no_version, Mime::XML, /Version is required when updating/)
  end

  def test_from_xml_id_zero
    id_list = ["", "0", "00", "0.0", "a"]
    id_list.each do |id|
      zero_id = "<osm><way id='#{id}' changeset='33' version='23' /></osm>"
      check_error_attr_new_ok(zero_id, Mime::XML, /ID of way cannot be zero when updating/, OSM::APIBadUserInput)
    end
  end
  
  def test_from_xml_no_text
    check_error_attr("", Mime::XML, /Must specify a string with one or more characters/)
  end
  
  def test_from_xml_no_k_v
    nokv = "<osm><way id='23' changeset='23' version='23'><tag /></way></osm>"
    check_error_attr(nokv, Mime::XML, /tag is missing key/)
  end
  
  def test_from_xml_no_v
    no_v = "<osm><way id='23' changeset='23' version='23'><tag k='key' /></way></osm>"
    check_error_attr(no_v, Mime::XML, /tag is missing value/)
  end
  
  def test_from_xml_duplicate_k
    dupk = "<osm><way id='23' changeset='23' version='23'><tag k='dup' v='test' /><tag k='dup' v='tester' /></way></osm>"
    message_create = assert_raise(OSM::APIDuplicateTagsError) {
      Way.from_format(Mime::XML, dupk, true)
    }
    assert_equal "Element way/ has duplicate tags with key dup", message_create.message
    message_update = assert_raise(OSM::APIDuplicateTagsError) {
      Way.from_format(Mime::XML, dupk, false)
    }
    assert_equal "Element way/23 has duplicate tags with key dup", message_update.message
  end

  #### utility methods ####

  # most attributes report faults in the same way, so we can abstract
  # that to a utility method
  def check_error_attr(content, format, message_regex)
    message_create = assert_raise(OSM::APIBadXMLError) {
      Way.from_format(format, content, true)
    }
    assert_match message_regex, message_create.message
    message_update = assert_raise(OSM::APIBadXMLError) {
      Way.from_format(format, content, false)
    }
    assert_match message_regex, message_update.message
  end

  # some attributes are optional on newly-created elements, but required
  # on updating elements.
  def check_error_attr_new_ok(content, format, message_regex, exception_class=OSM::APIBadXMLError)
    assert_nothing_raised(exception_class) {
      Way.from_format(format, content, true)
    }
    message_update = assert_raise(exception_class) {
      Way.from_format(format, content, false)
    }
    assert_match message_regex, message_update.message
  end
end
