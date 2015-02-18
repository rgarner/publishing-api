package main

import (
	"encoding/json"
	"io"
	"io/ioutil"
	"net/http"

	"github.com/gorilla/mux"

	"github.com/alphagov/publishing-api/contentstore"
	"github.com/alphagov/publishing-api/urlarbiter"
)

type ContentStoreController struct {
	arbiter      *urlarbiter.URLArbiter
	contentStore *contentstore.ContentStoreClient
}

type ContentStoreRequest struct {
	PublishingApp string `json:"publishing_app"`
}

func NewContentStoreController(arbiterURL, contentStoreURL string) *ContentStoreController {
	return &ContentStoreController{
		arbiter:      urlarbiter.NewURLArbiter(arbiterURL),
		contentStore: contentstore.NewClient(contentStoreURL),
	}
}

func (cs *ContentStoreController) PutContentStoreRequest(w http.ResponseWriter, r *http.Request) {
	urlParameters := mux.Vars(r)

	requestBody, err := ioutil.ReadAll(r.Body)
	if err != nil {
		renderer.JSON(w, http.StatusInternalServerError, err)
		return
	}

	var contentStoreRequest *ContentStoreRequest
	if err := json.Unmarshal(requestBody, &contentStoreRequest); err != nil {
		switch err.(type) {
		case *json.SyntaxError:
			renderer.JSON(w, http.StatusBadRequest, err)
		default:
			renderer.JSON(w, http.StatusInternalServerError, err)
		}
		return
	}

	if !cs.registerWithURLArbiter(urlParameters["base_path"], contentStoreRequest.PublishingApp, w) {
		// errors already written to ResponseWriter
		return
	}

	cs.doContentStoreRequest("PUT", r.URL.Path, requestBody, w)
}

// Register the given path and publishing app with the URL arbiter.  Returns
// true on success.  On failure, writes an error to the ResponseWriter, and
// returns false
func (cs *ContentStoreController) registerWithURLArbiter(path, publishingApp string, w http.ResponseWriter) bool {
	urlArbiterResponse, err := cs.arbiter.Register(path, publishingApp)
	if err != nil {
		switch err {
		case urlarbiter.ConflictPathAlreadyReserved:
			renderer.JSON(w, http.StatusConflict, urlArbiterResponse)
		case urlarbiter.UnprocessableEntity:
			renderer.JSON(w, 422, urlArbiterResponse) // Unprocessable Entity.
		default:
			renderer.JSON(w, http.StatusInternalServerError, err)
		}
		return false
	}
	return true
}

func (cs *ContentStoreController) GetContentStoreRequest(w http.ResponseWriter, r *http.Request) {
	cs.doContentStoreRequest("GET", r.URL.Path, nil, w)
}

func (cs *ContentStoreController) DeleteContentStoreRequest(w http.ResponseWriter, r *http.Request) {
	cs.doContentStoreRequest("DELETE", r.URL.Path, nil, w)
}

// data will be nil for requests without bodies
func (cs *ContentStoreController) doContentStoreRequest(httpMethod string, path string, data []byte, w http.ResponseWriter) {
	resp, err := cs.contentStore.DoRequest(httpMethod, path, data)
	if err != nil {
		renderer.JSON(w, http.StatusInternalServerError, err)
	}
	defer resp.Body.Close()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}