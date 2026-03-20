import QtQuick 2.0
import Sailfish.Silica 1.0

import "../."
import "../components/"
import "../delegates/"

Page {
    property bool loading: false
    property bool initialized: false

    property var editorialCollections: []
    property var featuredPlaylists: []
    property var featuredProgramSets: []
    property string featuredProgramSetTitle
    property var items: []
    property string itemsTitle
    property var mostPlayed: []
    property var stageItems: []

    id: page

    allowedOrientations: Orientation.All


    function load() {
        loading = true
        Api.graphql(`
            {
              editorialCollections(
                first: 10,
                filter: { isActive: { equalTo: true } }
              ) {
                nodes {
                  id
                  title
                  synopsis
                  image { url1X1 }
                  numberOfElements
                  items(first: 5) {
                    nodes {
                      id
                      title
                      synopsis
                      duration
                      publishDate
                      image { url1X1 }
                    }
                  }
                }
              }
            }
        `, null, function(data, status) {
            loading = false

            if (status !== 200) {
                //% "Failed to fetch data"
                notify.show(qsTrId("id-failed-to-fetch-data"))
                return
            }

            featuredProgramSets = data["data"]["editorialCollections"]["nodes"]
            featuredProgramSetTitle = "Collections" // or from data?

            items = [] // TODO: query for items
            itemsTitle = "Items"

            mostPlayed = [] // TODO
            stageItems = [] // TODO

            initialized = true
        })
    } 

    Timer {
        id: timer
        interval: 10000
        repeat: true
        running: true

        onTriggered: slideView.incrementCurrentIndex()
    }

    PageBusyIndicator {
        running: loading && !initialized

        Label {
            anchors {
                top: parent.bottom
                topMargin: Theme.paddingLarge
                horizontalCenter: parent.horizontalCenter
            }
            color: Theme.highlightColor
            //% "Loading data..."
            text: qsTrId("id-loading-data")
        }
    }

    SilicaFlickable {
        PullDownMenu {
            busy: loading
            MenuItem {
                //% "About"
                text: qsTrId("id-about")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                //% "Settings"
                text: qsTrId("id-settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                //% "Reload"
                text: qsTrId("id-reload")
                onClicked: load()
            }
            MenuItem {
                //% "Search"
                text: qsTrId("id-search")
                onClicked: pageStack.push(Qt.resolvedUrl("SearchPage.qml"))
            }
        }

        anchors.fill: parent
        contentHeight: contentColumn.height

        opacity: (loading && !initialized) ? 0.0 : 1.0

        Behavior on opacity {
            FadeAnimation { }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingLarge

            Item {
                width: parent.width
                height: width

                SlideshowView {
                    BusyIndicator {
                        anchors.fill: parent
                        running: loading
                    }
                    id: slideView


                    clip: true

                    itemWidth: width

                    model: stageItems
                    delegate: BackgroundItem {
                        width: slideView.itemWidth
                        height: slideView.height

                        RemoteImage {
                            anchors.fill: parent
                            source: Global.applyDataToImageLink(modelData["_links"]["mt:image"]["href"], "1x1", width)

                            Rectangle {
                                anchors.fill: parent
                                color: "black"
                                opacity: 0.4
                            }

                            Column {
                                x: Theme.paddingLarge
                                width: parent.width -2*x
                                anchors {
                                    bottom: parent.bottom
                                    bottomMargin: pageIndicator.height + 3 * Theme.paddingLarge
                                }
                                spacing: Theme.paddingLarge

                                Label {
                                    width: parent.width
                                    font.pixelSize: Theme.fontSizeTiny
                                    font.bold: true
                                    text: modelData["tracking"]["play"]["show"]
                                }
                                Label {
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    text: modelData["title"]
                                }
                                Row {
                                    width: parent.width
                                    spacing: Theme.paddingMedium

                                    Label {
                                        font.pixelSize: Theme.fontSizeTiny
                                        font.bold: true
                                        text: Global.getDurationString(modelData["tracking"]["play"]["clipLength"])
                                    }
                                    Label {
                                        font.pixelSize: Theme.fontSizeTiny
                                        font.bold: true
                                        text: "|"
                                    }
                                    Label {
                                        font.pixelSize: Theme.fontSizeTiny
                                        font.bold: true
                                        text: modelData["tracking"]["play"]["channel"]
                                    }
                                }
                            }
                        }
                        onClicked: pageStack.push(Qt.resolvedUrl("PodcastDetailsPage.qml"), {
                                                            contentId: modelData["id"]
                                                          })
                    }
                }

                PageIndicator {
                    id: pageIndicator
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: Theme.paddingLarge * 2
                    }
                    count: slideView.count
                    currentIndex: slideView.currentIndex
                }
            }

            CollectionsSlideView {
                title: itemsTitle
                model: items
                contentType: "programsets"
            }

            CollectionsSlideView {
                title: featuredProgramSetTitle
                model: featuredProgramSets
                contentType: "editorialcollections"
            }

            SectionHeader {
                visible: !loading
                //% "Most Played"
                text: qsTrId("id-most-played")
                font.pixelSize: Theme.fontSizeLarge
            }

            Column {
                width: parent.width

                Repeater {
                    model: mostPlayed

                    PodcastDelegate {
                        bookmarked: false // DB.isBookmarked(modelData["id"])
                        downloaded: false // DB.isDownloaded(modelData["id"])
                        podcastId: modelData["id"]
                        image: Global.applyDataToImageLink(modelData["_links"]["mt:image"]["href"].toString(), "1x1", width)
                        title: modelData["title"]
                        subtitle: modelData["_embedded"]["mt:programSet"]["title"] + " - "
                                  + modelData["_embedded"]["mt:programSet"]["_embedded"]["mt:publicationService"]["title"]
                        info: new Date(modelData["publicationStartDateAndTime"]).toLocaleDateString(Qt.locale())
                              + " - "
                              + Global.getDurationString(modelData["duration"])

                        onClicked: pageStack.push(Qt.resolvedUrl("PodcastDetailsPage.qml"), {
                                                              contentId: modelData["id"]
                                                            })
                    }
                }
            }

            Item {
                width: 1
                height: Theme.paddingMedium + playerWidget.visibleHeight
            }
        }

        VerticalScrollDecorator {}
    }

    onStatusChanged: if (status === PageStatus.Active) pageStack.pushAttached(Qt.resolvedUrl("CategoriesListPage.qml"))

    Component.onCompleted: load()
}
