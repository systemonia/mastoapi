import private/common
import apps

const prefix = "/oauth"

type
  Token* = object ## Defined in https://docs.joinmastodon.org/entities/Token/
    access_token*, token_type*: string
    scope*: string
    created_at*: DateTime ## This is converted from a Unix Epoch timestamp

proc createTokenRaw*(instance: string, app: Application, user_code: string = ""): Option[JsonNode] = 
  
  let url = instance & prefix & "/token"

  var data = newMultipartData()
  
  # Depending on whether user_code is set.
  # Make grant_type authorization_code or client_credentials
  if user_code != "":
    data.set({
      "grant_type": "authorization_code",
      "code": user_code
    })
  else:
    data.set({"grant_type": "client_credentials"})

  data.set({
    "client_id": app.client_id,
    "client_secret": app.client_secret,
    "redirect_uri": app.redirect_uri,
    "scopes": app.scopes
  })

  var response = newHttpClient().request(url, HttpPost, "", nil, data)

  if getCode(response) != 200: return none(JsonNode)

  return some(getBody(response).parseJson())

proc createToken*(instance: string, app: Application, user_code: string = ""): Option[Token] = 
  ## https://docs.joinmastodon.org/methods/oauth/#token
  ## the `user_code` parameter should only be filled if you want to use a user authorization code.
  ## Do not fill it if you want app-only access, ie `client_credentials` grant type.
  ## Remember to make sure the api.app object is filled with createApp() or importApp()
  ## Otherwise the API will throw out an error.
  let jayson = createTokenRaw(instance, app, user_code)

  if isNone(jayson): return none(Token)

  let json = jayson.get()

  var obj: Token;

  # Check the most important part for validity.
  if not json.isValid("access_token"): return none(Token)

  json.safeString(obj.access_token, "access_token")
  json.safeString(obj.token_type, "token_type")  
  obj.scope = app.scopes

  json.unixTimestamp(obj.created_at, "created_at")

  return some(obj)