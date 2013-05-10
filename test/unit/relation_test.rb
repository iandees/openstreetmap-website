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

  def test_from_json_no_id
    noid = {'relations'=>{'changeset' => 2, 'version' => 1}}.to_json
    check_error_attr_new_ok(noid, Mime::JSON, /ID is required when updating/)
  end

  def test_from_json_no_changeset_id
    nocs = {'relations'=>{'id' => 123, 'version' => 23}}.to_json
    check_error_attr(nocs, Mime::JSON, /Changeset id is missing/)
  end

  def test_from_json_no_version
    no_version = {'relations'=>{'id' => 123, 'changeset' => 23}}.to_json
    check_error_attr_new_ok(no_version, Mime::JSON, /Version is required when updating/)
  end

  ## NOTE: the "double attribute" errors which we raise in XML mode don't apply here
  ## the last value will silently overwrite any previous values. not sure if this should
  ## be considered a bug, but needs reporting in the dev docs.

  def test_from_json_id_zero
    # first, testing some things which are 'zero' or otherwise invalid due to being
    # invalid JSON
    id_list = ["", "00", "a"]
    id_list.each do |id|
      zero_id = '{"relations":{"id":' + id + ',"changeset":33,"version":33}}'
      check_error_attr(zero_id, Mime::JSON, /Cannot parse valid relation from xml string/)
    end

    # second, testing some things which are also 'zero', but should be rejected at
    # a later check due to them being 'zero'.
    id_list = ["0", "0.0", "\"\"", "\"0\"", "\"00\"", "\"0.0\"", "\"a\""]
    id_list.each do |id|
      zero_id = '{"relations":{"id":' + id + ',"changeset":33,"version":33}}'
      check_error_attr_new_ok(zero_id, Mime::JSON, /ID of relation cannot be zero when updating/, OSM::APIBadUserInput)
    end
  end

  def test_from_json_no_text
    check_error_attr("", Mime::JSON, /A JSON text must at least contain two octets/)
  end

  # check that whether an item is in the JSON as a string or as a number
  # doesn't make any difference to whether the relation object parses.
  def test_from_json_quoting_unimportant
    data = {'id' => 123, 'changeset' => 23, 'version' => 23}
    data.keys.each do |k|
      data_quoted = data.clone
      data_quoted[k] = data_quoted[k].to_s
      assert_nothing_raised(OSM::APIBadUserInput) {
        Relation.from_format(Mime::JSON, {'relations'=>data_quoted}.to_json, true)
      }
      assert_nothing_raised(OSM::APIBadUserInput) {
        Relation.from_format(Mime::JSON, {'relations'=>data_quoted}.to_json, false)
      }
    end
  end

  def test_to_json
    rel = current_relations(:multi_tag_relation)
    data = JSON.parse(rel.to_format(Mime::JSON))

    assert_equal(rel.id, data['relations']['id'])
    assert_equal(rel.version, data['relations']['version'])
    assert_equal(rel.changeset.id, data['relations']['changeset'])
    assert_equal(rel.changeset.user.id, data['relations']['uid'])
    assert_equal(rel.changeset.user.display_name, data['relations']['user'])
    assert_equal(rel.visible, data['relations']['visible'])
    assert_equal(rel.timestamp, Time.parse(data['relations']['timestamp']))
    assert_equal(rel.tags, data['relations']['tags'])
    assert_equal(rel.members.map{|t,i,r| {'type'=>t, 'ref'=>i, 'role'=>r}}, data['relations']['members'])
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
