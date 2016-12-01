$ ->

  if window.profile == "courses"
    $('.nav-tabs a[href="#tab2"]').tab('show')

  if window.profile == "books"
    $('.nav-tabs a[href="#tab3"]').tab('show')

  is_edit = false
  # edit-btn pressdown
  $(".edit-btn").click ->
    $(".edit-box").toggle()
    $(".unedit-box").toggle()
    $(".finish-btn").toggle()
    $(".edit-btn").hide()
    $("#name-input").val($("#name-span").text())
    $("#age-input").val($("#age-span").text())
    $("#gender-input").val($("#gender-span").text())
    $("#phone-input").val($("#phone-span").text())
    $("#parent-input").val($("#parent-span").text())
    $("#address-input").val($("#address-span").text())
    is_edit = true

  $("#kids-message").click ->
    if is_edit
      $(".finish-btn").show()
    else
      $(".edit-btn").show()

  $("#course-review").click ->
    $(".edit-btn").hide()
    $(".finish-btn").hide()

  $("#book-review").click ->
    $(".edit-btn").hide()
    $(".finish-btn").hide()

  $(".details").click ->
    span = $(this).find("span")
    row = $(this).closest("tr")
    status = row.next()
    status.toggle()
    if span.hasClass("triangle-down")
      span.removeClass("triangle-down").addClass("triangle-up")
    else
      span.removeClass("triangle-up").addClass("triangle-down")

  $("#pay-late-fee").click ->
    $.postJSON(
      '/staff/clients/' + window.uid + '/pay_latefee',
      { },
      (data) ->
        console.log data
        if data.success
          $("#pay-late-fee").addClass("hide")
          $("#no-late-fee").removeClass("hide")
          $.page_notification("操作完成")
        else
          $.page_notification("服务器出错")
    )

  $("#deposit-btn").click ->
    # pay deposit
    $.postJSON(
      '/staff/clients/' + window.uid + '/pay_deposit',
      { },
      (data) ->
        console.log data
        if data.success
          window.location.href = "/staff/clients/" + window.uid + "?profile=books&code=" + DONE
        else
          $.page_notification("服务器出错")
    )


  $("#deposit-refund").click ->
    # refund deposit
    $.postJSON(
      '/staff/clients/' + window.uid + '/refund_deposit',
      { },
      (data) ->
        console.log data
        if data.success
          window.location.href = "/staff/clients/" + window.uid + "?profile=books&code=" + DONE
        else
          $.page_notification("服务器出错")
    )


