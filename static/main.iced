MAX_IN_MEMORY_FILESIZE = 100 * 1024 * 1024
CHUNK_SIZE = 800
PING_INTERVAL = 1000
DIRECT_CONNECT_TIMEOUT = 5 * PING_INTERVAL

MESSAGE =
  CHUNK: "CHUNK"
  RECEIVE_FILE: "RECEIVE_FILE"
  RECEIVED_FILE: "RECEIVED_FILE"
  FILE_COMPLETE: "FILE_COMPLETE"
  RECEIVED_CHUNK: "RECEIVED_CHUNK"
  PING: "PING"
  PONG: "PONG"

STATE =
  DISCONNECTED: "disconnected"
  WAITING: "waiting"
  CONNECTED: "connected"

STATUS =
  WAITING: "waiting"
  ACTIVE: "active"
  ERROR: "error"
  COMPLETE: "complete"

DIRECTION =
  RECEIVE: "receive"
  SEND: "send"

EVENT =
  TRANSFER_START: "transfer_start"
  TRANSFER_PROGRESS: "transfer_progress"
  TRANSFER_ERROR: "transfer_error"
  TRANSFER_COMPLETE: "transfer_complete"


class Emitter extends EventEmitter
  emit: (args...) ->
    # l "emit:", @, args
    super

rxt.importTags()

g = {}
g.file_name = rx.cell("")
g.progress = rx.cell(0)
g.sent_chunk_count = rx.cell(0)
g.missing_chunk_count = rx.cell(0)
g.received_chunk_count = rx.cell(0)
g.total_chunk_count = rx.cell(0)

main = () ->
  # user_id = sessionStorage["user_id"]
  # if not user_id
  #     user_id = PUBNUB.uuid()
  #     sessionStorage["user_id"] = user_id

  user_id = PUBNUB.uuid()
  l "user_id:", user_id

  if window.location.search
    params = decode_query_string(window.location.search.substring(1))
    channel_id = params["channel"]
  else
    channel_id = PUBNUB.uuid()
    history.pushState({}, "", window.location.pathname + "?channel=#{channel_id}")

  l "channel_id:", channel_id

  window.pubnub = PUBNUB.init(
    subscribe_key: "sub-c-f7f7f93c-f5b9-11e2-b68e-02ee2ddab7fe"
    publish_key: "pub-c-7e59a5a7-3363-4311-923e-d857f97a1e46"
    uuid: user_id
    # ssl: true
  )

  $(document).bind('drop dragover', (e) ->
    e.preventDefault()
  )

  on_event = (e) ->
    l "event:", e

  window.orbital = new Orbital(user_id, channel_id)


class Orbital extends Emitter
  constructor: (@user_id, @channel_id) ->
    @user_ids = []
    @set_state(STATE.DISCONNECTED)

    @queued_messages = []

    @outgoing_transfers = []
    @incoming_transfers = []
    @send_in_progress = false

    @add_counters()

    pubnub.subscribe
      channel: @channel_id
      presence: (m) =>
        if m.uuid == @user_id
          return

        # it seems that we can believe leaves and timeouts, but joins
        # appear to be suspect
        if m.action == "join"
          @send(m.uuid, MESSAGE.PING)

        if m.action == "timeout" or m.action == "leave"
          @user_ids = _.without(@user_ids, m.uuid)
          @render()

      connect: (m) =>
        @connected()

      disconnect: (m) =>
        @set_state(STATE.DISCONNECTED)

      reconnect: (m) =>
        @connected()

      error: (m) =>
        e "error:", m

      callback: (m) =>
        l "message:", m

        if m.target_user_id != @user_id
          return

        if m.type == MESSAGE.PING
          # just in case we didn't have this user
          # (presence seems to fail to send a join message sometimes)
          @user_ids.push(m.source_user_id)
          @send(m.source_user_id, MESSAGE.PONG)

        else if m.type == MESSAGE.PONG
          @user_ids.push(m.source_user_id)

        else if m.type == MESSAGE.RECEIVE_FILE
          @receive_file(m.source_user_id, m.payload.transfer_id, m.payload.file_info)

        else if m.type == MESSAGE.FILE_COMPLETE
          # transfer complete, send the next file if one is ready
          @send_in_progress = false
          @send_next_file()

        else
          e "unrecognized channel message", m

        # remove duplicates
        @user_ids = _.uniq(@user_ids)
        @render()

  add_counters: ->
    $('body').append(
      div rx.bind -> "File Name: #{g.file_name.get()}"
      div rx.bind -> "Progress: #{g.progress.get()}"
      div rx.bind -> "Sent Chunk Count: #{g.sent_chunk_count.get()}"
      div rx.bind -> "Missing Chunk Count: #{g.missing_chunk_count.get()}"
      div rx.bind -> "Received Chunk Count: #{g.received_chunk_count.get()}"
      div rx.bind -> "Total Chunk Count: #{g.total_chunk_count.get()}"
    )

  connected: ->
    @set_state(STATE.WAITING)
    for args in @queued_messages
      @send(args...)

  set_state: (@state) ->
    @emit("state", @state)

  send: (user_id, type, payload) ->
    if @state == STATE.DISCONNECTED
      @queued_messages.push([user_id, type, payload])
      return

    pubnub.publish
      channel: @channel_id
      message:
        source_user_id: @user_id
        target_user_id: user_id
        type: type
        payload: payload

  render: () ->
    users_elem = $("#users")
    users_elem.empty()
    for user_id in @user_ids
      userbox_elem = $("<div class='userbox' id='##{user_id}'>#{user_id}<div class='filetransfers'></div></div>")
      @setup_userbox_handlers(userbox_elem, user_id)
      users_elem.append(userbox_elem)

  setup_userbox_handlers: (elem, user_id) ->
    elem.on "dragover", (event) =>
      event.preventDefault()
    # https://github.com/blueimp/jQuery-File-Upload/wiki/Drop-zone-effects
    # elem.on "dragenter", (event) =>
    #   l "dragenter"
    # elem.on "dragleave", (event) =>
    #   l "dragleave"
    elem.on "drop", (event) =>
      event.preventDefault()
      for file in event.originalEvent.dataTransfer.files
        @send_file(user_id, file)

  send_next_file: ->
    for transfer in @outgoing_transfers
      if transfer.status == STATUS.WAITING
        @send_in_progress = true
        transfer.start()
        break

  send_file: (user_id, file) ->
    transfer = new Transfer
      id: PUBNUB.uuid()
      direction: DIRECTION.SEND
      user_id: user_id
      file_or_info: file

    transfer.addListeners
      start: =>
        g.file_name.set(file.name)
        @send(user_id, MESSAGE.RECEIVE_FILE, transfer_id: transfer.id, file_info: transfer.file_info)
      progress: (percent) =>
        g.progress.set(percent)
      error: (message) =>
        e "failed to transfer:", message
        @send_in_progress = false

    l "sending_file:", file, @send_in_progress
    if not @send_in_progress
      @send_in_progress = true
      transfer.start()

    @outgoing_transfers.push(transfer)

  receive_file: (user_id, transfer_id, file_info) ->
    transfer = new Transfer
      id: transfer_id
      direction: DIRECTION.RECEIVE
      user_id: user_id
      file_or_info: file_info

    transfer.addListeners
      start: =>
        g.file_name.set(file_info.name)
      progress: (percent) =>
        g.progress.set(percent)
      complete: ({file_info, chunks}) =>
        @send(user_id, MESSAGE.FILE_COMPLETE, transfer_id: transfer_id)
        @save_file(file_info, chunks)
      error: (message) =>
        e "failed to transfer:", message

    transfer.start()  # incoming transfers are started immediately
    @incoming_transfers.push(transfer)

  save_file: (file_info, chunks) ->
    blob = new Blob(chunks, type: file_info.type)
    link = document.createElement("a")
    link.href = window.URL.createObjectURL(blob)
    link.download = file_info.name
    link.click()


class Transfer extends Emitter
  constructor: ({@id, @direction, @user_id, @file_or_info}) ->
    @status = STATUS.WAITING
    @creation_time = new Date()

    if @direction == DIRECTION.SEND
      @controller = new FileSender
        file: @file_or_info
        user_id: @user_id

      @file_info = @controller.file_info
    else
      @controller = new FileReceiver
        file_info: @file_or_info
        user_id: @user_id

      @file_info = @file_or_info

  start: ->
    @start_time = new Date()
    @status = STATUS.ACTIVE
    @controller.addListeners
      progress: (percent) =>
        @emit "progress", percent
      complete: (args...) =>
        @status = STATUS.COMPLETE
        @end_time = new Date()
        @emit "complete", args...
      error: (message) =>
        @emit "error", message
    @controller.start()
    @emit "start"


class FileSender extends Emitter
  constructor: ({@file, @user_id}) ->
    @file_info = {
      name: @file.name
      size: @file.size
      type: @file.type
      chunk_count: Math.ceil(@file.size/CHUNK_SIZE)
    }
    @reader = new FileReader(@file)
    @sent_chunk_count = 0
    @chunk_count = @file_info.chunk_count
    @chunk_received = new Array(@chunk_count)
    @received_chunk_count = 0

  start: ->
    g.sent_chunk_count.set(@sent_chunk_count)
    g.total_chunk_count.set(@chunk_count)
    g.received_chunk_count.set(@received_chunk_count)

    @connection = new UserConnection(user_id: @user_id)
    @connection.addListeners
      connected: =>
        @send_until_complete()
      timeout: =>
        @emit "error", "connection timed out"
      message: (m) =>
        if m.type == MESSAGE.RECEIVED_CHUNK
          n = m.payload.n
          if not @chunk_received[n]?
            @chunk_received[n] = true
            @received_chunk_count++
            g.received_chunk_count.set(@received_chunk_count)
            @emit "progress", @received_chunk_count/@chunk_count
        else
          e "unrecognized direct message", m
    @connection.connect()

  send_until_complete: ->
    while true
      # keep sending until the other side has received all chunks
      chunk_numbers = @get_remaining_chunks()
      if chunk_numbers.length == 0
        break
      await @send_chunks(chunk_numbers, defer _)
    @connection.close()
    @emit "complete"

  get_remaining_chunks: ->
    chunks = []
    for status, n in @chunk_received
      if not status?
        chunks.push(n)
    return chunks

  send_chunks: (chunk_numbers, callback) ->
    for n in chunk_numbers
      startOffset = n * CHUNK_SIZE
      endOffset = _.min([startOffset + CHUNK_SIZE, @file.size])
      await @read_chunk(startOffset, endOffset, defer chunk)
      data = array_buffer_to_base64(chunk)
      if not @connection.connected
        # timeout or other error has occurred
        return
      @connection.send(MESSAGE.CHUNK, n: n, data: data)

      @sent_chunk_count += 1
      g.sent_chunk_count.set(@sent_chunk_count)

    callback()

  read_chunk: (startOffset, endOffset, callback) ->
    @reader.onload = -> callback(this.result)
    @reader.readAsArrayBuffer(@file.slice(startOffset, endOffset))


class FileReceiver extends Emitter
  constructor: ({@file_info, @user_id}) ->
    @chunk_count = @file_info.chunk_count
    @received_chunk_count = 0
    @missing_chunk_count = @chunk_count
    @chunks = new Array(@chunk_count)

  start: ->
    g.total_chunk_count.set(@chunk_count)
    g.missing_chunk_count.set(@missing_chunk_count)
    g.received_chunk_count.set(@received_chunk_count)

    @connection = new UserConnection(user_id: @user_id)
    @connection.addListeners
      timeout: =>
        @emit "error", "connection timed out"
      message: (m) =>
        if m.type == MESSAGE.CHUNK
          @on_chunk(m.payload.n, m.payload.data)
        else
          e "unrecognized direct message", m
    @connection.connect()

  on_chunk: (n, data) ->
    @connection.send(MESSAGE.RECEIVED_CHUNK, n: n)

    @received_chunk_count++
    g.received_chunk_count.set(@received_chunk_count)

    # if we already have the chunk, forget it
    if @chunks[n]?
      return

    @chunks[n] = base64_to_array_buffer(data)

    @missing_chunk_count--
    g.missing_chunk_count.set(@missing_chunk_count)

    @emit "progress", (@chunk_count - @missing_chunk_count)/@chunk_count

    if @missing_chunk_count == 0
      @connection.close()
      @emit("complete", file_info: @file_info, chunks: @chunks)


class UserConnection extends Emitter
  constructor: ({@user_id}) ->
    @connected = false

  connect: ->
    pubnub.subscribe
      user: @user_id
      callback: (m) =>
        if m.type == "PING"
          @reset_timeout_timer()
          if not @connected
            @connected = true
            @emit "connected"
        else
          @emit "message", m

    @ping_interval = set_interval(PING_INTERVAL, => @send("PING"))
    @reset_timeout_timer()

  reset_timeout_timer: ->
    @stop_timeout_timer()
    @timeout_timer = set_timeout(DIRECT_CONNECT_TIMEOUT, =>
      @close()
      @emit "timeout"
    )

  stop_timeout_timer: ->
    clearTimeout @timeout_timer

  send: (type, payload) ->
    if type != "PING" and not @connected
      throw Error("send on closed connection")

    pubnub.publish
      user: @user_id
      message:
        type: type
        payload: payload

  close: ->
    pubnub.unsubscribe
      user: @user_id
    @stop_timeout_timer()
    clearTimeout @ping_interval
    @connected = false


# read_as_data_url = (file, callback) ->
#   reader = new window.FileReader()
#   reader.onload = (event) ->
#     callback(event.target.result)
#   reader.readAsDataURL(file)

# read_as_array_buffer = (file, callback) ->
#   reader = new window.FileReader()
#   reader.onload = (event) ->
#     callback(event.target.result)
#   reader.readAsArrayBuffer(file)

array_buffer_to_base64 = (buffer) ->
  # TODO: try this
  # binary = String.fromCharCode.apply(null, new Uint8Array(buffer))
  # return window.btoa(binary)

  binary = ""
  bytes = new Uint8Array(buffer)
  len = bytes.byteLength
  i = 0
  while i < len
    binary += String.fromCharCode(bytes[i])
    i++
  return window.btoa(binary)

base64_to_array_buffer = (data) ->
  binary = window.atob(data)
  buffer = new ArrayBuffer(binary.length)
  buffer_view = new Uint8Array(buffer);
  for i in [0...binary.length]
    buffer_view[i] = binary.charCodeAt(i)
  return buffer

decode_query_string = (query_string) ->
  params = {}
  for pair in query_string.split("&")
      [k, v] = pair.split("=")
      params[decodeURIComponent(k)] = decodeURIComponent(v)
  return params

l = (args...) ->
  console.log(args...)

e = (args...) ->
  console.error(args...)

set_timeout = (milliseconds, callback) ->
  setTimeout(callback, milliseconds)

set_interval = (milliseconds, callback) ->
  setInterval(callback, milliseconds)

# window.log = (args...) ->
#   $(document.body).append($("<div>#{getTimeStamp()}: #{args.join(' ')}</div>"))

# getTimeStamp = ->
#   now = new Date()
#   (now.getMonth() + 1) + "/" + (now.getDate()) + "/" + now.getFullYear() + " " + now.getHours() + ":" + (if (now.getMinutes() < 10) then ("0" + now.getMinutes()) else (now.getMinutes())) + ":" + (if (now.getSeconds() < 10) then ("0" + now.getSeconds()) else (now.getSeconds()))


$(document).ready(main)
