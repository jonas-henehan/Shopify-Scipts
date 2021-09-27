# ================================ Customizable Settings ================================
# ================================================================
# Show Gateways For Customer Tag
#
# If we have a matching customer, the entered gateway(s) will be
# shown, and all others will be hidden. Otherwise, the entered
# gateway(s) will be hidden.
#
#   - 'customer_tag_match_type' determines whether we look for the customer
#     to be tagged with any of the entered tags or not. Can be:
#       - ':include' to check if the customer is tagged
#       - ':exclude' to make sure the customer isn't tagged
#   - 'customer_tags' is a list of customer tags to trigger the
#     campaign
#   - 'gateway_match_type' determines whether the below strings
#     should be an exact or partial match. Can be:
#       - ':exact' for an exact match
#       - ':partial' for a partial match
#   - 'gateway_names' is a list of strings to identify gateways
# ================================================================
SHOW_GATEWAYS_FOR_CUSTOMER_TAG = [
  {
    customer_tag_match_type: :include,
    customer_tags: ["NET30"],
    gateway_match_type: :exact,
    gateway_names: ["NET30"],
  },
]

# ================================ Script Code (do not edit) ================================
# ================================================================
# CustomerTagSelector
#
# Finds whether the supplied customer has any of the entered tags.
# ================================================================
class CustomerTagSelector
  def initialize(match_type, tags)
    @comparator = match_type == :include ? 'any?' : 'none?'
    @tags = tags.map { |tag| tag.downcase.strip }
  end

  def match?(customer)
    customer_tags = customer.tags.map { |tag| tag.downcase.strip }
    (@tags & customer_tags).send(@comparator)
  end
end

# ================================================================
# GatewayNameSelector
#
# Finds whether the supplied gateway name matches any of the
# entered names.
# ================================================================
class GatewayNameSelector
  def initialize(match_type, gateway_names)
    @comparator = match_type == :exact ? '==' : 'include?'
    @gateway_names = gateway_names.map { |name| name.downcase.strip }
    puts @gateway_names
  end

  def match?(payment_gateway)
    @gateway_names.any? { |name| payment_gateway.name.downcase.strip.send(@comparator, name) }
  end
end

# ================================================================
# ShowGatewaysForCustomerTagCampaign
#
# If the customer has any of the entered tags, the entered gateways
# are shown/hidden depending on the entered settings
# ================================================================
class ShowGatewaysForCustomerTagCampaign
  def initialize(campaigns)
    @campaigns = campaigns
  end

  def run(cart, payment_gateways)
    @campaigns.each do |campaign|
      customer_tag_selector = CustomerTagSelector.new(
        campaign[:customer_tag_match_type],
        campaign[:customer_tags],
      )

      customer_match = cart.customer.nil? ? false : customer_tag_selector.match?(cart.customer)
      
      next if customer_match

      gateway_name_selector = GatewayNameSelector.new(
        campaign[:gateway_match_type],
        campaign[:gateway_names],
      )

      payment_gateways.delete_if do |payment_gateway|
        gateway_name_selector.match?(payment_gateway)
      end
    end
  end
end

CAMPAIGNS = [
  ShowGatewaysForCustomerTagCampaign.new(SHOW_GATEWAYS_FOR_CUSTOMER_TAG),
]

CAMPAIGNS.each do |campaign|
  campaign.run(Input.cart, Input.payment_gateways)
end

Output.payment_gateways = Input.payment_gateways
