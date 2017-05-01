# News APNS

This is a service that allows you to run an APNS server that will send APNS notifications to devices with articles for which particular legislators have been mentioned. Once per day news articles will be updated and APNS messages sent. The previous days news articles will be purged at this time.

The /register endpoint allows devices to register to recieve notifications for legislators specified in the body. See the following example for the structure of the JSON body:
```
{
	"token": "318EC25079DF49D1B1G61846826B726C6849E8E648PB1742E5FAB69BDAC45DA",
		"legislators": [
		{
	    "fullname": "Elena Parent",
	    "chamber": "Upper"
		},
		{
	    "fullname": "Stacey Abrams",
	    "chamber": "Lower"
		}
		]
}
```
* This will be made generic in a future version so it will only require a query not "legislator" detail

The endpoint will return the currnet list of articles in the response. The token is optional and you can hit register endpoint with an empty token to get the articles in a "pull" fashion. This is useful if the user declines the remote notification permission. 

## 📖 Vapor Documentation

Visit the Vapor web framework's [documentation](http://docs.vapor.codes) for instructions on how to use this package.

## 💧 Vapor Community

Join the welcoming community of fellow Vapor developers in [slack](http://vapor.team).

## 🔧 Compatibility

This package has been tested on macOS and Ubuntu.
