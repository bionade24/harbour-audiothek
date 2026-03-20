import QtQuick 2.0
import Sailfish.Silica 1.0
import QtMultimedia 5.6

import "../."

ListModel {
    property var content
    property string contentKey
    property string contentType
    property bool loading: false
    property int numberOfElements: 0
    property string cursor: null
    property bool hasNextPage: false

    property string query

    function load() {
        if (query.length === 0) return

        loading = true
        cursor = null

        if (query.includes("/search")) {
            // Parse search query
            var params = query.split("?")[1].split("&")
            var searchText = decodeURIComponent(params.find(p => p.startsWith("query=")).split("=")[1])
            Api.graphql(`
                query($query: String!, $first: Int!, $after: String) {
                  search(query: $query, first: $first, after: $after) {
                    totalCount
                    pageInfo {
                      hasNextPage
                      endCursor
                    }
                    nodes {
                      __typename
                      ... on Item {
                        id
                        title
                        synopsis
                        duration
                        publishDate
                        image { url1X1 }
                        audios { url downloadUrl mimeType allowDownload }
                        programSet { title }
                        publicationService { title }
                      }
                      ... on ProgramSet {
                        id
                        title
                        synopsis
                        numberOfElements
                        image { url1X1 }
                      }
                    }
                  }
                }
            `, { query: searchText, first: 20, after: null }, function(data, status) {
                loading = false
                if (status !== 200) {
                    notify.show(qsTrId("id-failed-to-fetch-data"))
                    return
                }
                clear()
                var searchResult = data["data"]["search"]
                content = { items: { nodes: searchResult.nodes }, numberOfElements: searchResult.totalCount }
                numberOfElements = searchResult.totalCount
                cursor = searchResult.pageInfo.endCursor
                hasNextPage = searchResult.pageInfo.hasNextPage
                addPodcasts(searchResult.nodes)
            })
        } else {
            // Fallback to REST for other queries
            Api.request(query.replace("{offset}", String(0)), function(data, status) {
                loading = false
                if (status !== 200) {
                    notify.show(qsTrId("id-failed-to-fetch-data"))
                    return
                }
                clear()
                content = data["data"][contentKey]
                if (data["data"][contentKey].hasOwnProperty("numberOfElements")) {
                    numberOfElements = data["data"][contentKey]["numberOfElements"]
                } else if (data["data"][contentKey]["items"].hasOwnProperty("numberOfElements")) {
                    numberOfElements = data["data"][contentKey]["items"]["numberOfElements"]
                }
                addPodcasts(data["data"][contentKey]["items"]["nodes"])
            })
        }
    }

    function loadMore() {
        if (query.length === 0) return
        if (!hasNextPage || loading) return

        loading = true

        if (query.includes("/search")) {
            var params = query.split("?")[1].split("&")
            var searchText = decodeURIComponent(params.find(p => p.startsWith("query=")).split("=")[1])
            Api.graphql(`
                query($query: String!, $first: Int!, $after: String) {
                  search(query: $query, first: $first, after: $after) {
                    pageInfo {
                      hasNextPage
                      endCursor
                    }
                    nodes {
                      __typename
                      ... on Item {
                        id
                        title
                        synopsis
                        duration
                        publishDate
                        image { url1X1 }
                        audios { url downloadUrl mimeType allowDownload }
                        programSet { title }
                        publicationService { title }
                      }
                      ... on ProgramSet {
                        id
                        title
                        synopsis
                        numberOfElements
                        image { url1X1 }
                      }
                    }
                  }
                }
            `, { query: searchText, first: 20, after: cursor }, function(data, status) {
                loading = false
                if (status !== 200) {
                    notify.show(qsTrId("id-failed-to-fetch-data"))
                    return
                }
                var searchResult = data["data"]["search"]
                content.items.nodes = content.items.nodes.concat(searchResult.nodes)
                cursor = searchResult.pageInfo.endCursor
                hasNextPage = searchResult.pageInfo.hasNextPage
                addPodcasts(searchResult.nodes)
            })
        } else {
            // Fallback
            Api.request(query.replace("{offset}", String(count)), function(data, status) {
                loading = false
                if (status !== 200) {
                    notify.show(qsTrId("id-failed-to-fetch-data"))
                    return
                }
                var obj = content
                obj["items"]["nodes"] = content["items"]["nodes"].concat(data["data"][contentKey]["items"]["nodes"])
                content = obj
                addPodcasts(data["data"][contentKey]["items"]["nodes"])
            })
        }
    }

    function addPodcast(item) {
        var obj = new Object
        obj["duration"] = item["duration"]
        obj["id"] = item["id"]
        obj["image"] = item["image"]["url1X1"]
        //obj["publicationStartDateAndTime"] = item["publicationStartDateAndTime"]
        obj["sharingUrl"] = item["sharingUrl"]
        obj["synopsis"] = item["synopsis"]
        obj["title"] = item["title"]
        obj["url"] = item["audios"][0]["url"]
//        obj["bookmarked"] = DB.isPodcastBookmarked(item["id"])
//        obj["completed"] = DB.isPodcastCompleted(item["id"])
//        obj["position"] = DB.getPodcastPosition(item["id"])
        DB.getPodcastStatus(obj)
        listModel.append(obj)
    }

    function addPodcasts(items) {
        items.forEach(function(item) {
            addPodcast(item)
        })
    }

    function setPodcasts(items) {
        reset()
        addPodcasts(items)
    }

    function addPodcastObject(obj) {
        listModel.append(obj)
    }

    function addPodcastObjects(objs) {
        objs.forEach(function(obj) { listModel.append(obj) })
    }

    function setPodcastObjects(objs) {
        reset()
        addPodcastObjects(objs)
    }

    function reset() {
        listModel.clear()
    }

    id: listModel
}
