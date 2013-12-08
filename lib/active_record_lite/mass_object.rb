class MassObject

  # takes a list of attributes.
  # adds attributes to whitelist.
  def self.my_attr_accessible(*attributes)
    self.my_attr_accessor(*attributes)
    @whitelist ||= []
    attributes.each do |attribute|
      @whitelist << attribute.to_sym
    end
  end

  # takes a list of attributes.
  # makes getters and setters
  def self.my_attr_accessor(*attributes)
    attributes.each do |attribute|
      define_method(attribute) do
        self.instance_variable_get("@#{attribute}")
      end
      define_method("#{attribute}=") do |value|
        self.instance_variable_set("@#{attribute}", value)
      end
    end
  end


  # returns list of attributes that have been whitelisted.
  def self.attributes
    @whitelist ||= []
  end

  # takes an array of hashes.
  # returns array of objects.
  def self.parse_all(results)
    results.map do |attr_hash|
      self.new(attr_hash)
    end
  end

  # takes a hash of { attr_name => attr_val }.
  # checks the whitelist.
  # if the key (attr_name) is in the whitelist, the value (attr_val)
  # is assigned to the instance variable.
  def initialize(params = {})
    obj = super()
    params.each do |attribute, value|
      unless self.class.attributes.include?(attribute.to_sym)
        raise "mass assignment to unregistered attribute #{attribute}"
      end
      self.send("#{attribute}=", value)
    end
    obj

  end
end
