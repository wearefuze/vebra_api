module Vebra
  class Branch

    attr_reader :attributes, :client

    # Parse a Nokogiri XML fragment to extract the branch attributes

    def initialize(nokogiri_xml, client)
      @client     = client
      @attributes = Vebra.parse(nokogiri_xml)
      set_attributes!
    end

    # Parse an XML response using Nokogiri to extract additional
    # attributes for this branch

    def get_branch
      nokogiri_xml = client.call(url).parsed_response.css('branch')
      @attributes.merge!(Vebra.parse(nokogiri_xml))
      @attributes[:address] = {
        :street   => @attributes.delete(:street),
        :town     => @attributes.delete(:town),
        :county   => @attributes.delete(:county),
        :postcode => @attributes.delete(:postcode)
      }
      set_attributes!
    end

    def get_properties
      target_url = "#{url}/property"
      xml = client.call(target_url).parsed_response
      # build a collection of Property objects
      xml.css('properties property').map { |p| Property.new(p, self) }
    end

    private

    def set_attributes!
      @attributes.each do |key, value|
        self.class.send(:define_method, key) do
          @attributes[key]
        end unless respond_to?(key)
      end
    end

  end
end