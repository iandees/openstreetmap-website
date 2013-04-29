require File.dirname(__FILE__) + '/../test_helper'

class RelationTest < ActiveSupport::TestCase
  api_fixtures
  
  def test_relation_count
    assert_equal 8, Relation.count
  end
  
  def test_from_xml_no_id
    noid = "<osm><relation version='12' changeset='23' /></osm>"
    check_error_attr_new_ok(noid, Mime::XML, /ID is required when updating/)
  end
  
  def test_from_xml_no_changeset_id
    nocs = "<osm><relation id='123' version='12' /></osm>"
    check_error_attr(nocs, Mime::XML, /Changeset id is missing/)
  end
  
  def test_from_xml_no_version
    no_version = "<osm><relation id='123' changeset='23' /></osm>"
    check_error_attr_new_ok(no_version, Mime::XML, /Version is required when updating/)
  end
  
  def test_from_xml_id_zero
    id_list = ["", "0", "00", "0.0", "a"]
    id_list.each do |id|
      zero_id = "<osm><relation id='#{id}' changeset='332' version='23' /></osm>"
      check_error_attr_new_ok(zero_id, Mime::XML, /ID of relation cannot be zero when updating/, OSM::APIBadUserInput)
    end
  end
  
  def test_from_xml_no_text
    check_error_attr("", Mime::XML, /Must specify a string with one or more characters/)
  end
  
  def test_from_xml_no_k_v
    nokv = "<osm><relation id='23' changeset='23' version='23'><tag /></relation></osm>"
    check_error_attr(nokv, Mime::XML, /tag is missing key/)
  end
  
  def test_from_xml_no_v
    no_v = "<osm><relation id='23' changeset='23' version='23'><tag k='key' /></relation></osm>"
    check_error_attr(no_v, Mime::XML, /tag is missing value/)
  end
  
  def test_from_xml_duplicate_k
    dupk = "<osm><relation id='23' changeset='23' version='23'><tag k='dup' v='test'/><tag k='dup' v='tester'/></relation></osm>"
    message_create = assert_raise(OSM::APIDuplicateTagsError) {
      Relation.from_xml(dupk, true)
    }
    assert_equal "Element relation/ has duplicate tags with key dup", message_create.message
    message_update = assert_raise(OSM::APIDuplicateTagsError) {
      Relation.from_xml(dupk, false)
    }
    assert_equal "Element relation/23 has duplicate tags with key dup", message_update.message
  end

  #### utility methods ####

  # most attributes report faults in the same way, so we can abstract
  # that to a utility method
  def check_error_attr(content, format, message_regex)
    message_create = assert_raise(OSM::APIBadXMLError) {
      Relation.from_format(format, content, true)
    }
    assert_match message_regex, message_create.message
    message_update = assert_raise(OSM::APIBadXMLError) {
      Relation.from_format(format, content, false)
    }
    assert_match message_regex, message_update.message
  end

  # some attributes are optional on newly-created elements, but required
  # on updating elements.
  def check_error_attr_new_ok(content, format, message_regex, exception_class=OSM::APIBadXMLError)
    assert_nothing_raised(exception_class) {
      Relation.from_format(format, content, true)
    }
    message_update = assert_raise(exception_class) {
      Relation.from_format(format, content, false)
    }
    assert_match message_regex, message_update.message
  end
end
