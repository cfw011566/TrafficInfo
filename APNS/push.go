package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"strconv"
	"strings"

	"github.com/garyburd/redigo/redis"
	"github.com/timehop/apns"
)

type RoadEvent struct {
	UID        string
	Region     string
	SrcDetail  string
	AreaNm     string
	Direction  string
	HappenDate string
	HappenTime string
	ModDttm    string
	RoadType   string
	Road       string
	Comment    string
	X1         string
	Y1         string
}

type AllEvents struct {
	Version string
	Count   float64
	Result  []*RoadEvent
}

//const trafficURL = "http://210.69.35.216/data/api/pbs/"
const trafficURL = "http://od.moi.gov.tw/data/api/pbs/"
const redisIPPort = "127.0.0.1:6379"

// filed name
const fieldRegion = "region"
const fieldAreaNm = "area-name"
const fieldSrcDetail = "src-detail"
const fieldRoad = "road"
const fieldDirection = "direction"
const fieldRoadType = "road-type"
const fieldHappenDatetime = "happen-datetime"
const fieldModifyDatetime = "modify-datetime"
const fieldComment = "comment"
const fieldLongitude = "longitude"
const fieldLatitude = "latitude"
const ttl = 60 * 60 * 8

func main() {
	var pushPtr = flag.Bool("p", false, "push notification")
	flag.Parse()

	apnsConn, err := apns.NewClientWithFiles(apns.SandboxGateway, "cert.pem", "key-noenc.pem")
	if err != nil {
		fmt.Println("Could not create client", err.Error())
	}

	redisConn, err := redis.Dial("tcp", redisIPPort)
	defer redisConn.Close()
	if err != nil {
		panic(err)
	}

	newEvents := updateTrafficEvent(redisConn)
	//	newEvents = append(newEvents, "10503310079-2", "10503310170-0", "10503310161-0", "10503310152-0")
	if len(newEvents) == 0 {
		log.Printf("no new events\n")
		return
	}
	fmt.Println(newEvents)

	if *pushPtr {
		log.Printf("pushing...\n")
		pushNewEvent(newEvents, redisConn, apnsConn)
	}
}

func updateTrafficEvent(conn redis.Conn) []string {
	var newEvents []string
	var events AllEvents
	var key string
	var happenDatetime string
	var longitude string
	var latitude string

	resp, err := http.Get(trafficURL)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	contents, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		panic(err)
	}

	err = json.Unmarshal(contents, &events)
	if err != nil {
		log.Printf("json unmarshal: %v\n", err)
		return newEvents
	}

	for _, v := range events.Result {
		//		log.Printf("%s %s", v.UID, v.AreaNm)
		key = fmt.Sprintf("event:%s", v.UID)
		exist, err := redis.Int64(conn.Do("EXISTS", key))
		if err != nil {
			log.Printf("EXISTS error: %v\n", err)
			return newEvents
		}
		if exist == 0 {
			//			fmt.Println("new event : ", v.UID)
			newEvents = append(newEvents, v.UID)
		}
		if len(v.X1) == 0 || len(v.Y1) == 0 {
			longitude = "0.0"
			latitude = "0.0"
		} else {
			longitude = v.X1
			latitude = v.Y1
		}
		happenDatetime = v.HappenDate + " " + v.HappenTime
		conn.Do("HMSET", key, fieldRegion, v.Region, fieldAreaNm, v.AreaNm, fieldSrcDetail, v.SrcDetail, fieldRoad, v.Road, fieldDirection, v.Direction, fieldRoadType, v.RoadType, fieldHappenDatetime, happenDatetime, fieldModifyDatetime, v.ModDttm, fieldComment, v.Comment, fieldLongitude, longitude, fieldLatitude, latitude)
		conn.Do("EXPIRE", key, ttl)
	}

	return newEvents
}

func pushNewEvent(newEvents []string, conn redis.Conn, client apns.Client) {
	tokens, err := redis.Strings(conn.Do("KEYS", "keyword:*"))
	if err != nil {
		log.Printf("KEYS error: %v\n", err)
		return
	}
	if len(tokens) == 0 {
		return
	}
	for _, key := range tokens {
		var count uint
		var token string
		var boolOnce bool
		var tokenRegion string
		var tokenPattern string
		var eventRegion string
		var eventAreaNm string
		var eventComment string

		token = key[8:]
		reply, err := redis.Values(conn.Do("HMGET", key, "Once", "Region", "Pattern"))
		if err != nil {
			log.Printf("HMGET error: %v\n", err)
			return
		}
		redis.Scan(reply, &boolOnce, &tokenRegion, &tokenPattern)

		for _, id := range newEvents {
			eventid := "event:" + id
			eventReply, err := redis.Values(conn.Do("HMGET", eventid, "region", "area-name", "comment"))
			if err != nil {
				log.Printf("new event HMGET: %v\n", err)
				continue
			}
			redis.Scan(eventReply, &eventRegion, &eventAreaNm, &eventComment)
			//			log.Printf("%s Region %s AreaNm %s\n", eventid, eventRegion, eventAreaNm)

			if tokenRegion == "A" || tokenRegion == eventRegion {
				if len(eventAreaNm) > 0 && strings.Contains(eventAreaNm, tokenPattern) {
					count++
				}
				if len(eventAreaNm) == 0 && strings.Contains(eventComment, tokenPattern) {
					count++
				}
			}
		}

		//		log.Printf("%s has %d\n", token, count);

		if count > 0 {
			p := apns.NewPayload()
			p.APS.Alert.Body = strconv.FormatUint(uint64(count), 10) + "個新路況符合條件:" + regionString(tokenRegion) + "/" + tokenPattern
			p.APS.Badge.Set(count)
			m := apns.NewNotification()
			m.Payload = p
			m.DeviceToken = token
			m.Priority = apns.PriorityImmediate

			client.Send(m)
			log.Printf("send %d to %s\n", count, token)
		}

	}
}

func regionString(region string) string {
	switch region {
	case "A":
		return "全區"
	case "N":
		return "北區"
	case "M":
		return "中區"
	case "S":
		return "南區"
	case "E":
		return "東區"
	default:
		return ""
	}
}
