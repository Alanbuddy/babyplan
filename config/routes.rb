Rails.application.routes.draw do

  mount RuCaptcha::Engine => "/rucaptcha"

  get 'welcome/index'
  get 'welcome/test'
  get 'welcome/kidscenter'
  get 'welcome/frontpage'
  get 'welcome/usercenter'
  get 'welcome/centerbook'
  get 'welcome/register'
  get 'welcome/signin'
  get 'welcome/centernotice'
  get 'welcome/haidianbook'
  get 'welcome/fengtaicenter'
  get 'welcome/centercourse'
  get 'welcome/robotclass'
  get 'welcome/evaluate'
  get 'welcome/robotcourse'
  get 'welcome/haidiancenter'
  get 'welcome/noticedescription'
  get 'welcome/mybook'
  get 'welcome/mycourse'
  get 'welcome/searchresult'
  get 'welcome/editdemo'
  get 'welcome/searchlink'
  get 'welcome/systemmessage'
  get 'welcome/collect'



  get 'welcome/managecenter'

  resources :centers do
  end

  resources :courses do
  end

  namespace :client do
    resources :users do
    end
    resources :sessions do
      collection do
        get :signin_page
        get :signup_page
      end
    end
    resources :infos do
    end
    resources :centers do
    end
  end

  namespace :admin do
    resources :sessions do
      collection do
        get :signout
        post :forget_password
      end
      member do
        post :reset_password
      end
    end
    resources :staffs do
      member do
        put :change_center
        put :change_status
      end
    end
    resources :announcements do
      member do
        post :set_publish
      end
    end
    resources :centers do
      member do
        post :set_available
        get :set_current
      end
    end
    resources :courses do
      member do
        post :set_available
        get :get_calendar
      end
    end
    resources :books do
    end
  end

  namespace :staff do
    resources :sessions do
      member do
        post :verify
        post :reset_password
      end
      collection do
        post :signup
        post :forget_password
        get :signout
      end
    end

    resources :courses do
      collection do
        get :get_id_by_name
      end
      member do
        post :set_available
      end
    end

    resources :books do
      member do
        post :set_available
        post :update_cover
        post :update_back
      end
    end

    resources :clients do
      member do
        post :verify
      end
    end

    resources :announcements do
      member do
        post :set_publish
      end
    end
  end

  resources :materials do
  end

  resources :accounts do
    member do
      post :activate
    end
  end


  resources :topics do
    member do
      post :upvote
    end
  end

  


  
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'staff/sessions#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'
  get '/admin', to: 'admin/sessions#index'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
