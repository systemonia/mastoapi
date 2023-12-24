import private/common

const prefix = "/api/v1/apps"

type
  Application* = object ## Defined in https://docs.joinmastodon.org/entities/Application/
    name*, website*, vapid_key*, client_id*, client_secret*: string
    scopes*, redirect_uri*: string # These are stored just in case the client needs to check a permission or something.

proc createAppRaw*(instance: string, name: string, uris: string = "urn:ietf:wg:oauth:2.0:oob", scopes:string = "", website: string = ""): Option[JsonNode] =
  let url = instance & prefix
  
  # Fill out form data
  var data = newMultipartData()
  data.set({
    "client_name": name,
    "redirect_uris": uris,
    "scopes": scopes,
    "website": website
  })

  var response = newHttpClient().request(url, HttpPost, "", nil, data)
  
  if getCode(response) != 200:
    return none(JsonNode)

  var json = getBody(response).parseJson()
  
  # We have to add this ourselves since the API does not supply it, and it's a good thing to do anyway.
  json.add("scope", newJString(scopes))
  return some(json)

proc createApp*(instance: string, name: string, uris: string = "urn:ietf:wg:oauth:2.0:oob", scopes:string = "", website: string = ""): Option[Application] =
  let jayson = createAppRaw(instance, name, uris, scopes, website)

  # Return nothing if the json is empty.
  if isNone(jayson): return none(Application)
  
  let json = jayson.get()

  var obj = Application()

  obj.name = name
  obj.redirect_uri = uris
  obj.website = website
  obj.scopes = scopes

  # If these two are missing, then don't bother.
  if not json.isValid("client_id"): return none(Application)
  if not json.isValid("client_secret"): return none(Application)

  json.safeString(obj.client_id, "client_id")
  json.safeString(obj.client_secret, "client_secret")
  json.safeString(obj.vapid_key, "vapid_key")

  return some(obj)

proc importApp*(json: string): Application =
  ## This allows you to take a JsonNode and convert it to an Application object
  ## seamlessly, which is useful for exporting with the provided exportApp() procedure
  ## and then importing at App restarts.
  ## *Note:* This is only meant to be used with exportApp() data
  return parseJson(json).to(Application)  

proc exportApp*(app: Application): string =
  ## This procedure takes a full Application object and turns it into JSON.
  ## This is useful for storing in a file, to be loaded later.
  ## So that you do not keep making new apps.
  return $(%* app)