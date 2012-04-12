# A Ruby API wrapper for the Vebra property management database

## Usage

Currently, the wrapper supports a single Vebra client and a single branch. Set up your client credentials in an initializer:

```ruby
# Gemfile
gem 'vebra', :git => 'git://github.com/rawnet/vebra_api.git'

# config/initializers/vebra.rb
Vebra.config do |config|
  # client credentials
  config.client_username = 'USER01'
  config.client_password = 'abc123'
  config.client_data_feed_id = 'MYAPI'
end
```

Enable debug mode (outputs to STDOUT) if you like:

```ruby
# config/initializers/vebra.rb
Vebra.config do |config|
  config.debug = true if Rails.env.development?
end
```

The gem will attempt to save persistent info such as the current active API token and the date & time when the properties were last updated. You can easily override the default temp directory:

```ruby
# config/initializers/vebra.rb
Vebra.config do |config|
  config.tmp_dir = Rails.root.join('tmp')
end
```

If you're running a Rails app and you're saving properties to a database, the gem can attempt to automate this process for you. By default, the gem expects the following structure in your models:

```ruby
class Property < ActiveRecord::Base
  belongs_to :address
  has_many :rooms
  has_many :files # "files" covers images, pdfs, floorplans, etc
  attr_accessible :vebra_ref, :description # etc ...
end

class Address < ActiveRecord::Base
  has_one :property
  attr_accessible :name # etc ...
end

class Room < ActiveRecord::Base
  belongs_to :property
  attr_accessible :name # etc ...
end

class File < ActiveRecord::Base
  belongs_to :property
  attr_accessible :name # etc ...
  
  def remote_file_url=(url)
    # handle saving the remote file locally
    # it is highly recommended that you do *not* simply link to the remote url within your app
  end
end
```

If you have different model names, you can override them:

```ruby
class Property < ActiveRecord::Base
  has_many :attachments
end

class Attachment < ActiveRecord::Base
  belongs_to :property
end

Vebra.config do |config|
  config.models.file_class = :attachment
  config.models.file_attachment_method = :file # becomes "remote_file_url" to support Carrierwave (or similar)
  config.models.property_files_method = :attachments
end
```

The gem will parse and convert the data supplied by Vebra into a more user-friendly structure (for an example, see `spec/support/expected_output.rb`). When developing your model structure, it is important to keep in mind the format of the data output by the gem. A suggested model structure is as follows:

```ruby
class Property < ActiveRecord::Base
  # Serializers
  serialize :price_attributes
  serialize :bullets
  
  # Accessors
  attr_accessible :vebra_ref, :group, :price, :price_attributes, :available_on, :uploaded_on, :latitude, :longitude, :status, :property_type,
                  :furnished, :sold_on, :sold_price, :lease_ends_on, :garden, :parking, :bullets, :description
  
  # Associations
  belongs_to :address, :dependent => :destroy
  has_many :rooms, :dependent => :destroy
  has_many :attachments, :dependent => :destroy

  # Validations
  validates :vebra_ref, :uniqueness => true

  # uses the "money" gem to derive the currency
  def currency
    @currency ||= Money::Currency.new(price_attributes[:currency])
  end
end

class Address < ActiveRecord::Base
  # Accessors
  attr_accessible :name, :street, :town, :postcode

  # Associations
  has_one :property
end

class Room < ActiveRecord::Base
  # Serializers
  serialize :dimensions

  # Accessors
  attr_accessible :vebra_ref, :room_type, :name, :dimensions

  # Associations
  belongs_to :property
end

class Attachment < ActiveRecord::Base
  # Uploaders (using the "carrierwave" gem)
  mount_uploader :file, FileUploader

  # Accessors
  attr_accessible :type, :vebra_ref, :name, :remote_file_url

  # Associations
  belongs_to :property
end
```

### Vebra::Helpers.update_properties!

Also available via rake: `rake vebra:update_properties`

This (destructive) method fetches all properties for the current client and branch. If this method has been called previously, only the properties which have been changed since the last update will be retrieved. This is a destructive method which will attempt to update your ActiveRecord models accordingly.

### Vebra::Helpers.fetch_properties

This (non-destructive) method will return a collection of all properties (or just the properties updated since the last update). You can pass `true` to the method to force retrieving all properties. Note that you may wish to manually mark the last update date, as the gem will not do this automctically in this method:

```ruby
Vebra.set_last_updated_at(Time.now)
```

Alternatively, you can use the gem bypassing the helper methods altogether, receiving the raw XML output from Vebra:

```ruby
Vebra::API.get(url, auth_object)
```

The `auth_object` should be a hash containing the client's `:username`, `:password`, `:data_feed_id` and (optionally) `:token`

This method will handle the authentication (username:password-based or token-based) and will return a `Vebra::Response` object containing the original response (`response_object`) as well as a Nokogiri-parsed response (`parsed_response`).