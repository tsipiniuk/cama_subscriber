class Plugins::CamaSubscriber::FrontController < CamaleonCms::Apps::PluginsFrontController
  include Plugins::CamaSubscriber::MainHelper

  def subscribe
    msg = nil
    error = []
    unless params[:email].present?
      error = t(".email_required", default: 'Your email is required to subscribe for this newsletter')
    end

    group = params[:group_id].present? ? current_site.subscriber_groups.find(params[:group_id]) : current_site.subscriber_groups.first
    if group.items.where(email: params[:email]).present?
      error << t(".already_registered", default: 'You have already subscribed to this newsletter')
    end

    if error.present?
      respond_to do |format|
        format.html { flash[:error] = error.join("<br>"); redirect_to cama_root_url }
        format.json{ render json: {message: error.join("<br>"), error: true} }
      end
      return
    end

    item = current_site.subscriber_items.where(email: params[:email]).first
    unless item.present?
      item = current_site.subscriber_items.new(name: params[:name], email: params[:email])
      item.status = 'pending' if @plugin.get_option('needs_confirmation') == 1
      item.save!
      item.extra_values(params[:extra_values]) if params[:extra_values].present?
      if @plugin.get_option('needs_confirmation') == 1
        cama_send_email(params[:email], @plugin.get_option('welcome_subject'), {content: @plugin.get_option('welcome_msg') + "<a href='#{plugins_cama_subscriber_verify_url(key: '')}'></a>"})
        msg = t(".please_confirm_email", default: 'Your subscription is pending, please confirm your subscription from your email')
      end
    end

    group.item_groups.create(item_id: item.id)
    msg = msg || t('.you_have_subscribed', default: 'You have been subscribed successfully')
    respond_to do |format|
      format.html { flash[:notice] = msg;  redirect_to cama_root_url }
      format.json{ render json: {message: msg, error: false} }
    end
  end

  # confirm subscriber
  def verify
    xxx, xx, id_item  = Base64.decode64(params[:key]).split('/')
    current_site.subscriber_items.find(id_item).update(status: 'approved')
    flash[:notice] = t(".success_confirm", default: 'Your subscription was successfully confirmed.')
    redirect_to cama_root_url
  end

  def image_email
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"

    promotion_id, sent_promo_id  = Base64.decode64(params[:key]).split('/')
    begin
      promotion = current_site.subscriber_promotions.find(promotion_id)
      promotion.sent_promo_items.find(sent_promo_id).increment!
    rescue
    end
    send_file File.join(@plugin.settings['path'], 'lib', '1x1.png'), type: "image/png", disposition: "inline"
  end

  # unsubscribe from promotion
  def unsubscribe
    begin
      promotion_id, sent_promo_id  = Base64.decode64(params[:key]).split('/')
      promotion = current_site.subscriber_promotions.find(promotion_id)
      item = promotion.sent_promo_items.find(sent_promo_id).item
      item.item_groups.where(group_id: promotion.groups.pluck(:id)).destroy_all
    rescue
    end

    flash[:notice] = t('.you_have_unsubscribed', default: 'You have been unsubscribed successfully')
    redirect_to cama_root_url
  end

  # unsubscribe from all
  def unsubscribe_all
    begin
      promotion_id, sent_promo_id  = Base64.decode64(params[:key]).split('/')
      promotion = current_site.subscriber_promotions.find(promotion_id)
      item = promotion.sent_promo_items.find(sent_promo_id).item
      item.unsubscribe!
      item.item_groups.destroy_all
    rescue
    end

    flash[:notice] = t('.you_have_unsubscribed', default: 'You have been unsubscribed successfully')
    redirect_to cama_root_url
  end

  # add custom methods below
end
