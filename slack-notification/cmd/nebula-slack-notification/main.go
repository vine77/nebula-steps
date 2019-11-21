package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"

	"github.com/puppetlabs/nebula-sdk/pkg/log"
	"github.com/puppetlabs/nebula-steps/slack-notification/pkg/client"
)

type Spec struct {
	Apitoken string `json:"apitoken"`
	Channel  string `json:"channel"`
	Message  string `json:"message"`
	Username string `json:"username"`
}

func getSpec() (*Spec, error) {
	specUrl := os.Getenv("SPEC_URL")
	if "" == specUrl {
		return nil, errors.New("Missing required environment variable: SPEC_URL")
	}
	resp, err := http.Get(specUrl)
	if err != nil {
		return nil, errors.New(fmt.Sprintf("GET %s: %v", specUrl, err))
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, errors.New(fmt.Sprintf("GET %s: %v", specUrl, err))
	}
	if resp.StatusCode/100 != 2 {
		return nil, errors.New(fmt.Sprintf("GET %s -> %d: %v", specUrl, resp.StatusCode, err))
	}
	var spec Spec
	err = json.Unmarshal([]byte(body), &spec)
	if err != nil {
		return nil, errors.New(fmt.Sprintf("GET %s -> %s: %v", specUrl, body, err))
	}
	return &spec, nil
}

func main() {
	spec, err := getSpec()
	if nil != err {
		log.FatalE(err)
	}
	if "" == spec.Channel || "" == spec.Message || "" == spec.Apitoken {
		log.Fatal("Missing required fields. Expect spec to contain 'apitoken', 'channel' and 'message'")
	}
	if "" == spec.Username {
		spec.Username = "Nebula"
	}

	c := client.New(spec.Apitoken)
	_, err = c.Chat().PostMessage(
		client.PostMessageRequest{
			Channel:  spec.Channel,
			Text:     spec.Message,
			Username: spec.Username,
		})

	if nil != err {
		log.FatalE(err)
	}

	os.Exit(0)
}
