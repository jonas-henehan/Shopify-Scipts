# ========================= Modify Rural Delivery Shipping Rates =========================
#
#  This script will hide Rural Delivery shipping rates for non-RD shipping addresses and 
#  vice versa.
#
# ========================= Customizable settings =========================
#
#  The following parameters can be modified to change what address keywords you wish
#  to flag, and what shipping methods should be hidden
#
#   - address_selectors: They keywords to be flagged within the 'Address 1' (street) and
#                        'Address 2' (apartment, flat etc) fields. This must be struct-
#                        ured as an 'Array' with each keyword in double quotation marks
#                        and separated by commas. e.g., ["keyword_1", "keyword_2"]
#
#   - shipping_rate_selectors: An array of either keywords or exact names for the rural
#                        rates you wish to hide. This can be either keywords like "RD" and
#                        "rural" or exact shipping rate names like "Standard Rural Shipping"
#
#   - shipping_rate_match_type: Determines whether the above 'shipping_rate_selectors' sh-
#                       hould be matched exactly, or if partial matches are okay. Can be:
#                          - ':exact' for exact matches only
#                          - 'partial' to match any keywords
#
# ====== ALWAYS SAVE A WORKING BACKUP OF YOUR SCRIPT CODE BEFORE MODIFYING THESE SETTINGS ======

HIDE_RURAL_SHIPPING_RATES = [
  {
    address_selectors: ["RD", "Rural District", "Rural"],
    shipping_rate_selectors: ["Rural"],
    shipping_rate_match_type: :partial,
  }
]

# ========================= Script code  =========================
#
# ========================= DO NOT MODIFY =========================

# The AddressQualifier looks to see whether a customer has entered one of the 'address_sel-
# ectors' keywords

class AddressQualifier
  def initialize(selectors)
    @selectors = selectors.map { |selector| selector.downcase.strip }
  end

  def match?(address)
    address_fields = [address.address1, address.address2].map do |field|
      field.nil? ? "" : field.downcase
    end

    address_fields = address_fields.join(" ")
    @selectors.any? { |selector| address_fields.include?(selector) }
  end
end

# The RateNameSelector selects all the rates to hide based off the 'shipping_rate_selectors'
# based off the 'shipping_rate_match_type' being used

class RateNameSelector
  def initialize(match_type, rate_names)
    @match_type = match_type
    @comparator = match_type == :exact ? '==' : 'include?'
    @rate_names = rate_names.map { |name| name.downcase.strip }
  end

  def match?(shipping_rate)
    @rate_names.any? { |name| shipping_rate.name.downcase.send(@comparator, name) }
  end
end

# The HideRuralShippingRatesCampaign handles running both the address and rate name checks
# and hides different rates as required

class HideRuralShippingRatesCampaign
  def initialize(campaigns)
    @campaigns = campaigns
  end

  def run(cart, shipping_rates)
    address = cart.shipping_address

    # Here we skip out of making any changes if no shipping address is entered (i.e., di-
    # gital goods)
    next if address.nil?

    @campaigns.each do |campaign|
      # Next we check if the shipping address entered contains any of our keywords
      address_checker = AddressQualifier.new(campaign[:address_selectors])

      # Then we select all rates that contain/match our shipping_rate_selectors
      rate_name_selector = RateNameSelector.new(
        campaign[:shipping_rate_match_type],
        campaign[:shipping_rate_selectors]
      )

      # We define a rural_customer as someone who's address contained a keyword
      rural_customer = address_checker.match?(address)

      # Next we either hide the rural rates if they AREN'T a rural_customer, or hide
      # the NON-rural rates if they ARE
      unless rural_customer
        shipping_rates.delete_if do |rate|
          rate_name_selector.match?(rate)
        end
      else
        shipping_rates.delete_if do |rate|
          rate_name_selector.match?(rate) == false
        end
      end
    end
  end
end

CAMPAIGNS = [
  HideRuralShippingRatesCampaign.new(HIDE_RURAL_SHIPPING_RATES)
]

CAMPAIGNS.each do |campaign|
  campaign.run(Input.cart, Input.shipping_rates)
end

Output.shipping_rates = Input.shipping_rates