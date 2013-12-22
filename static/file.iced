CHUNK_SIZE = 1024*1024

class ChunkReader
    constructor: (@file) ->
        @reader = new FileReader(file)
        @offset = 0

    nextChunk: (callback) ->
        startOffset = @offset
        if startOffset >= @file.size
            return callback(null)
        endOffset = _.min([startOffset + CHUNK_SIZE, @file.size - 1])
        @reader.onload = () -> callback(@result)
        @reader.readAsArrayBuffer(@file.slice(startOffset, endOffset))
        @offset = endOffset + 1


window.loadFile = (dataTransfer, callback) ->
    if dataTransfer.files.length > 1
        console.log("too many files")
        return

    file = dataTransfer.files[0]
    chunks = []
    chunkReader = new ChunkReader(file)
    # spark = new SparkMD5.ArrayBuffer()
    while true
        await chunkReader.nextChunk(defer arrayBuffer)
        if not arrayBuffer?
            break
        chunks.push(arrayBuffer)
    callback(chunks)

getFileLength = (url, callback) ->
    xhr = new XMLHttpRequest()
    xhr.open("HEAD", url)
    xhr.onload = () ->
        length = parseInt(this.getResponseHeader("Content-Length"))
        callback(length)
    xhr.send()

blobToArrayBuffer = (blob, callback) ->
    fileReader = new FileReader()
    fileReader.onload = () ->
        callback(this.result)
    fileReader.readAsArrayBuffer(blob)

fileErrorCodeToString = (code) ->
  switch code
    when FileError.QUOTA_EXCEEDED_ERR
      return "QUOTA_EXCEEDED_ERR"
    when FileError.NOT_FOUND_ERR
      return "NOT_FOUND_ERR"
    when FileError.SECURITY_ERR
      return "SECURITY_ERR"
    when FileError.INVALID_MODIFICATION_ERR
      return "INVALID_MODIFICATION_ERR"
    when FileError.INVALID_STATE_ERR
      return "INVALID_STATE_ERR"
    else
      return "Unknown Error"

# errwrap = (func, args...) ->
#     callback = args.pop()

#     success = (a...) ->
#         callback(null, a...)
#     args.push(success)

#     failure = (a...) ->
#         callback(a...)
#     args.push(failure)

#     func(args...)

errwrap = (func, args...) ->
    callback = args.pop()

    success = (a...) ->
        callback(false, a...)
    args.push(success)

    failure = (a...) ->
        callback(true, a...)
    args.push(failure)

    console.log(args)
    func(args...)

deleteFile = (fileSystem, filename, callback) ->
    # try to delete the file, if it doesn"t work, just keep going
    fileSystem.root.getFile(filename, {create: false}, ((fileEntry) ->
        fileEntry.remove(callback, callback)
    ), callback)

createFile = (callback) ->
    errorHandler = (e) ->
      console.log("error: " + fileErrorCodeToString(e.code))

    await webkitStorageInfo.requestQuota(PERSISTENT, 1024 * 1024 * 1024, (defer size), errorHandler)
    await webkitRequestFileSystem(PERSISTENT, size, (defer fileSystem), errorHandler)
    await deleteFile(fileSystem, "tmpfile.zip", defer _)
    await fileSystem.root.getFile("tmpfile.zip", {create: true, exclusive: true}, (defer fileEntry), errorHandler)
    await fileEntry.createWriter((defer writer), errorHandler)

    callback(fileEntry, writer)
