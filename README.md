# Extend-VCC

- Extend.swift:

This file just cointains basic structures

- ExtendWebView.swift

This is the Swift UI sheet that is presented. It loads the Extend login page, once the user signs in it executues Javascript to scrape the access token. This can be used to access the Extend API. This route is much easier than Extend Auth. The JS executed is below:

```
let jsScript = """
function lookup(suffix) {
  const key = Object.keys(localStorage).find(
    (key) =>
      key.startsWith("CognitoIdentityServiceProvider") && key.endsWith(suffix)
  );
  if (!key) return null;
  return localStorage[key];
}
var accessToken = lookup("accessToken");
JSON.stringify({
    accessToken: accessToken
});
"""
```

- ExtendAPI.swift

This file contains the API requests/logic to fetch/create VCC from Extend. It also has a function in swift to fetch the card accounts on file. The extend website lets you ass upto 10 "Card accounts", these card accounts are linked to real AMEX credit cards. Each card account can have up to 500 VCC.


