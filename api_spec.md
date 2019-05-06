# API Documentation
RESTful JSON API

Root URI: https://commuter.gigalixirapp.com/api/v1

#### Error Response
```
{
  "code": "invalid_request_error",
  "message": "Your request couldn't be processed."
}
```


### Stations
Get list of system stations.

`GET /stations`

Parameters: None

Response Status Code: `200`
```
{
  "object": "station",
  "data": [
    {
      "id": 1,
      "code": "MONT",
      "name": "Montgomery St"
    },
    {
      "id": 1,
      "code": "EMBR",
      "name": "Embarcadero"
    }
  ]
}
```

### Commute
Validate commute between two stations.

`GET /commutes?orig=PHIL&dest=MONT`

Parameters
- `orig`: Station Code, string
- `dest`: Station Code, string

Response Status Code: `204`

### Advisory
Get system service advisory.

`GET /advisories`

Parameters: None

Response Status Code: `200`
```
{
  "advisory": "10 min delay at Embarcadero station.",
  "count": 1
}
```

### Departures
All departures leaving origin station going to destination.

`GET /departures?orig=PHIL&dest=MONT&count=10&real_time=true&device_id=ABCDEG`

Parameters:
- `orig`: Station Code, string
- `dest`: Station Code, string
- `count`: Number of results to display, integer (optional)
- `real_time`: Return real-time values, boolean (optional)
- `device_id`: APNS device id, string (optional)

Response Status Code: `200`
```
{
  "orig": {
    "id": 1,
    "code": "PHIL",
    "name": "Pleasant Hill/Contra Costa Center"
  },
  "dest": {
    "id": 2,
    "code": "MONT",
    "name": "Montgomery St"
  },
  "as_of": "2019-05-05 20:39:12",
  "includes_real_time": true,
  "departures": [
    {
      "trip_id": 1,
      "etd": "20:39:12",
      "etd_min": 8,
      "std": "20:38:12",
      "eta": "20:57:00",
      "duration_min": 19,
      "delay_min": 1,
      "length": 9,
      "final_dest_code": "SFIA",
      "headsign": "San Francisco Int'l Airport",
      "headsign_code": "SFIA",
      "stops": 14,
      "prior_stops": 5,
      "route_hex_color": "FAFAFA",
      "notify": false,
      "real_time": true
    }
  ]
}
```

### ETA
Estimated time of arrival at destination station based on coordinates.

`GET /eta?lat=37.774929&lon=-122.419418&orig=PHIL&dest=MONT`

Parameters
- `lat`: Latitude, float
- `lon`: Longitude, float
- `orig`: Station Code, string
- `dest`: Station Code, string

Response Status Code: `200`
```
{
  "next_station": {
    "id": 1,
    "code": "WOAK",
    "name": "West Oakland"
  },
  "next_station_eta_min": 4,
  "eta": "20:38:12",
  "eta_min": 19
}
```

### Notifications

#### Get Nofications
`GET /notifications?device_id=ABCDEF`

Parameters
- `device_id`: APNS device_id, string

Response Status Code: `200`
```
{
  "muted": false,
  "notifications": [
    {
      "id": 1,
      "descrip": "Weekdays departing PHIL at 6:28am"
    }
  ]
}
```


#### Add a Notification
`POST /notifications`

Parameters
- `device_id`: APNS device_id, string
- `trip_id`: Trip ID from `/departures`, integer
- `station_code`: Station Code, string

Response Status Code: `204`

#### Remove a Notification
`POST /notifications`

Parameters
- `device_id`: APNS device_id, string
- `trip_id`: Trip id from `/departures`, integer
- `station_code`: Station Code, string
- `remove`: `true`

Response Status Code: `204`

`DELETE /notifications/{id}`

Parameters
- `id`: Notification id from `/notifications`, integer

Response Status Code: `204`

#### Mute/Unmute Notifications
`POST /notifications/action`

Parameters
- `device_id`: APNS device_id, string
- `mute`: boolean

Response Status Code: `204`
