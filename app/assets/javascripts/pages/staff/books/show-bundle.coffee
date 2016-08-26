#= require wangEditor.min

$ ->

  editor = new wangEditor('edit-area')
  # editor.config.menus = $.map(wangEditor.config.menus, (item, key) ->
  #   if item == 'insertcode'
  #     return null
  #   if item == 'fullscreen'
  #     return null    
  #   item
  # )
  
  editor.config.menus = [
        'head',
        'img'
     ]

  editor.config.uploadImgUrl = '/materials'

  editor.config.uploadHeaders = {
    'Accept' : 'HTML'
  }

  editor.config.hideLinkImg = true

  editor.create()