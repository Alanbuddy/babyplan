
$ ->
  # forgotpassword
  $(".forget-password").click ->
    $("#signinModal").modal('hide')

  uid = ""
  timer = null
  wait = 60
  $(".close").click ->
    clearTimeout(timer)
    wait = 60
    $("#mobilecode").text("获取验证码")
    $("#mobilecode").addClass("unclicked")
    $("#mobilecode").removeClass("clicked")
    $("#mobilecode").attr("disabled", false)

    $("#mobile-code").text("获取验证码")
    $("#mobile-code").addClass("unclicked")
    $("#mobile-code").removeClass("clicked")
    $("#mobile-code").attr("disabled", false)

  
  # verifycode 60 sec reverse 
  time = (o) ->
    console.log wait
    $(o).attr("disabled", true)
    $(o).addClass("clicked")
    $(o).removeClass("unclicked")
    if wait == 0
      $(o).attr("disabled", false)
      $(o).text('获取验证码')
      wait = 60
      $(o).removeClass("clicked")
      $(o).addClass("unclicked")
    else
      $(o).text('重发(' + wait + ')')
      wait--
      timer = setTimeout (->
        time o
        return
      ), 1000
    return

  $("#mobilecode").click ->
    mobile = $("#signup-mobile").val()
    mobile_retval = $.regex.isMobile(mobile)
    console.log mobile_retval
    if mobile_retval == false
      $("#mobile-notice").css("visibility","visible")
      $("#signup-mobile").addClass("clicked-box")
      return
    $("#signup-mobile").removeClass("clicked-box")
    $.postJSON(
      '/staff/sessions/signup',
      {
        mobile: mobile
      },
      (data) ->
        console.log data
        if data.success
          $("#mobile-notice").css("visibility","hidden")
          uid = data.uid
          console.log uid
        #需要修改
        else
          $("#mobile-notice").text("该手机号已注册，请直接登陆").css("visibility","visible")     
          console.log $("#mobile-notice").text()
    )
    if timer != null
      clearTimeout(timer)
    time this

  check_signup_input = ->
    console.log "check_signup_input pressed"
    if $("#signup-name").val().trim() == "" ||
        $("#signup-address").val().trim() == "" ||
        $("#signup-mobile").val().trim() == "" ||
        $("#signup-mobilecode").val().trim() == "" ||
        $("#signup-password").val().trim() == "" ||
        $("#signup-confirm-password").val().trim() == "" ||
        uid == ""
      $("#signup").addClass("button-disabled")
      $("#signup").removeClass("button-enabled")
    else
      $("#signup").removeClass("button-disabled")
      $("#signup").addClass("button-enabled")

  toggle_password_tip = (wrong) ->
    if (wrong)
      $("#signup-password").addClass("clicked-box")
      $("#signup-confirm-password").addClass("clicked-box")
      $("#password-notice").css("visibility","visible")
    else
      $("#signup-password").removeClass("clicked-box")
      $("#signup-confirm-password").removeClass("clicked-box")
      $("#password-notice").css("visibility","hidden")

  $("#signup-name").keyup ->
    check_signup_input()
  $("#signup-address").keyup ->
    check_signup_input()
  $("#signup-mobile").keyup ->
    check_signup_input()
  $("#signup-mobilecode").keyup ->
    check_signup_input()
    $("#verify-code-notice").css("visibility","hidden")
  $("#signup-password").keyup ->
    toggle_password_tip(false)
    check_signup_input()
  $("#signup-confirm-password").keyup ->
    toggle_password_tip(false)
    check_signup_input()


  # register
  $("#signup").click ->
    if uid == ""
      # $.page_notification("欢迎！", 3000)
      return
    if $(this).hasClass("button-enabled") == false
      return
    name = $("#signup-name").val()
    center = $("#signup-address").val()
    password = $("#signup-password").val()
    verify_code = $("#signup-mobilecode").val()
    password_verify_code = $("#signup-confirm-password").val()
    
    if password != password_verify_code
      toggle_password_tip(true)
      return
    
    $.postJSON(
      '/staff/sessions/' + uid + '/verify',
      {
        name: name
        center: center
        password: password
        verify_code: verify_code
      },
      (data) ->
        if data.success
          $.page_notification("注册完成，请通知管理员分配儿童中心", 3000)
        else
          $("#verify-code-notice").text("验证码错误").css("visibility","visible")
      )
  $("#signup-signin").click ->
    $("#signinModal").modal('show')
    $("#signupModal").modal('hide')


  # forgetpassword user mobile verify
  $("#mobile-code").click ->
    mobile = $("#forget-mobile").val()
    mobile_retval = $.regex.isMobile(mobile)
    console.log mobile_retval
    if mobile_retval == false
      $("#forget-mobile-notice").css("visibility","visible")
      $("#forget-mobile").addClass("clicked-box")
      return
    $("#forget-mobile").removeClass("clicked-box")
    $.postJSON(
      '/staff/sessions/forget_password',
      {
        mobile: mobile
      },
      (data) ->
        console.log data
        if data.success
          $("#forget-mobile-notice").css("visibility","hidden")
          uid = data.uid
        else
          $("#forget-mobile-notice").text("该手机号未注册").css("visibility","visible")     
      )
    if timer != null
      clearTimeout(timer)
    time this

  toggle_forget_password_tip = (wrong) ->
    if (wrong)
      $("#forget-password").addClass("clicked-box")
      $("#forget-confirm-password").addClass("clicked-box")
      $("#forget-password-notice").css("visibility","visible")
    else
      $("#forget-password").removeClass("clicked-box")
      $("#forget-confirm-password").removeClass("clicked-box")
      $("#forget-password-notice").css("visibility","hidden")

  check_forget_signup_input = ->
    console.log "check_signup_input pressed"
    if $("#forget-mobile").val().trim() == "" ||
        $("#forget-mobilecode").val().trim() == "" ||
        $("#forget-password").val().trim() == "" ||
        $("#forget-confirm-password").val().trim() == "" ||
        uid == ""
      $("#forget").addClass("button-disabled")
      $("#forget").removeClass("button-enabled")
    else
      $("#forget").removeClass("button-disabled")
      $("#forget").addClass("button-enabled")

  $("#forget-mobile").keyup ->
    check_forget_signup_input()
  $("#forget-mobilecode").keyup ->
    check_forget_signup_input()
    $("#forget-verify-code-notice").css("visibility","hidden")
  $("#forget-password").keyup ->
    toggle_forget_password_tip(false)
    check_forget_signup_input()
  $("#forget-confirm-password").keyup ->
    toggle_forget_password_tip(false)
    check_forget_signup_input()

  # reset password
  $("#forget").click ->
    if uid == ""
      # $.page_notification("欢迎！", 3000)
      return
    if $(this).hasClass("button-enabled") == false
      return
    password = $("#forget-password").val()
    verify_code = $("#forget-mobilecode").val()
    password_verify_code = $("#forget-confirm-password").val()

    if password != password_verify_code
      toggle_forget_password_tip(true)
      return

    $.postJSON(
      '/staff/sessions/' + uid + '/reset_password',
      {
        password: password
        verify_code: verify_code
      },
      (data) ->
        if data.success
          $("#forgetModal").modal('hide')
          $("#signinModal").modal('show')
          $.page_notification("密码已重置，请登录", 3000)
        else
          $("#forget-verify-code-notice").text("验证码错误").css("visibility","visible")
      )
  $("#forget-register").click ->
    $("#forgetModal").modal('hide')
    $("#signupModal").modal('show')


  toggle_signin_password_tip = (wrong) ->
    if (wrong)
      $("#mobile").addClass("clicked-box")
      $("#password").addClass("clicked-box")
      $(".error-notice").css("visibility","visible")
    else
      $("#mobile").removeClass("clicked-box")
      $("#password").removeClass("clicked-box")
      $(".error-notice").css("visibility","hidden")

  check_signin_input = ->
    console.log "check_signin_input pressed"
    if $("#mobile").val().trim() == "" ||
        $("#password").val().trim() == ""
      $(".signin").addClass("button-disabled")
      $(".signin").removeClass("button-enabled")
    else
      $(".signin").removeClass("button-disabled")
      $(".signin").addClass("button-enabled")

  $("#mobile").keyup ->
    check_signin_input()
  $("#password").keyup ->
    toggle_signin_password_tip(false)
    check_signin_input()

  $(".signin").click ->
    if $(this).hasClass("button-enabled") == false
      return
    mobile = $("#mobile").val()
    password = $("#password").val()
    mobile_retval = $.regex.isMobile(mobile)
    console.log mobile_retval
    if mobile_retval == false
      $(".error-notice").css("visibility","visible")
      $("#mobile").addClass("clicked-box")
      return
    $("#mobile").removeClass("clicked-box")
    $.postJSON(
      '/staff/sessions',
      {
        mobile: mobile
        password: password
      },
      (data) ->
        if data.success
          $(".error-notice").css("visibility","hidden")
        else
          
          $(".error-notice").css("visibility","visible")
      )











    







  
