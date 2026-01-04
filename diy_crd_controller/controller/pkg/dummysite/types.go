package dummysite

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// DummySiteSpec defines the desired state of DummySite
type DummySiteSpec struct {
	// WebsiteURL is the URL to fetch HTML content from
	WebsiteURL string `json:"website_url"`
}

// DummySiteStatus defines the observed state of DummySite
type DummySiteStatus struct {
	// Ready indicates whether the site is ready to be accessed
	Ready bool `json:"ready,omitempty"`
	// URL is the service URL to access the site
	URL string `json:"url,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// DummySite is the Schema for the dummysites API
// +k8s:openapi-gen=true
type DummySite struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   DummySiteSpec   `json:"spec,omitempty"`
	Status DummySiteStatus `json:"status,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// DummySiteList contains a list of DummySite
type DummySiteList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []DummySite `json:"items"`
}