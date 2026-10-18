#!/usr/bin/env ruby
# Puts the newest processed GetGrip build in front of every tester.
#
#   ASC_API_KEY_JSON=tooling/fastlane/asc_api_key.json \
#     ruby tooling/scripts/testflight-distribute.rb ["What to test"]
#
# Internal testers get every build automatically (their group has access to
# all builds). This adds the "What to test" note, adds the build to the
# external group and submits it for TestFlight beta review. It never
# submits anything for App Store review.
require "jwt"; require "openssl"; require "json"; require "net/http"; require "uri"

APP_ID = "6754203402"
EXTERNAL_GROUP = "c19e3c91-2278-4604-90cb-180dc9007bf1"

key = JSON.parse(File.read(ENV.fetch("ASC_API_KEY_JSON")))
now = Time.now.to_i
TOKEN = JWT.encode({ iss: key["issuer_id"], iat: now, exp: now + 900, aud: "appstoreconnect-v1" },
  OpenSSL::PKey::EC.new(key["key"]), "ES256", { kid: key["key_id"], typ: "JWT" })

def api(method, path, body = nil, allow: [])
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  req = Net::HTTP.const_get(method.capitalize).new(uri)
  req["Authorization"] = "Bearer #{TOKEN}"; req["Content-Type"] = "application/json"
  req.body = body.to_json if body
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  return nil if allow.include?(res.code.to_i)
  raise "#{method} #{path} → #{res.code} #{res.body}" unless res.code.to_i < 300
  res.body.to_s.empty? ? {} : JSON.parse(res.body)
end

build = api("GET", "/v1/builds?filter[app]=#{APP_ID}&filter[processingState]=VALID&sort=-uploadedDate&limit=1")["data"].first
abort "No processed build yet" unless build
id, number = build["id"], build["attributes"]["version"]
puts "Build #{number}"

notes = ARGV[0] || "Latest GetGrip 1.1 beta. Please test widgets, the paywall (including Lifetime) and onboarding."
loc = api("GET", "/v1/builds/#{id}/betaBuildLocalizations")["data"].find { |l| l["attributes"]["locale"] == "en-US" }
if loc
  api("PATCH", "/v1/betaBuildLocalizations/#{loc['id']}", { data: { type: "betaBuildLocalizations", id: loc["id"], attributes: { whatsNew: notes } } })
else
  api("POST", "/v1/betaBuildLocalizations", { data: { type: "betaBuildLocalizations", attributes: { locale: "en-US", whatsNew: notes },
    relationships: { build: { data: { type: "builds", id: id } } } } })
end
puts "  What to test set"

# A freshly processed build takes a few minutes to become assignable to an
# external group; wait for it rather than failing.
added = false
20.times do
  added = !api("POST", "/v1/betaGroups/#{EXTERNAL_GROUP}/relationships/builds",
    { data: [{ type: "builds", id: id }] }, allow: [409, 422]).nil?
  break if added
  sleep 30
end
puts added ? "  Added to External testers" : "  Not yet assignable to External testers; internal testers have it"

sub = api("POST", "/v1/betaAppReviewSubmissions",
  { data: { type: "betaAppReviewSubmissions", relationships: { build: { data: { type: "builds", id: id } } } } }, allow: [409, 422])
# 409: already submitted. 422: an earlier build of this version is still in
# beta review; once that is approved, later builds usually need none.
puts sub ? "  Submitted for beta review: #{sub.dig('data', 'attributes', 'betaReviewState')}" : "  Beta review not needed or already pending"
