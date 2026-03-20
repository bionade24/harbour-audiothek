pragma Singleton
import QtQuick 2.0

Item {
    function request (endpoint, callback) {
        const url = "https://api.ardaudiothek.de" + endpoint
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = (function(myxhr) {
            return function() {
                if (myxhr.readyState !== 4) return

                if (myxhr.status === 308) {
                    const location = myxhr.getResponseHeader("Location")
                    request.call(myxhr, location, callback)
                    return
                }

                var data

                try {
                    data = JSON.parse(myxhr.responseText)
                } catch (e) {
                    data = myxhr.responseText
                }

                callback(data, myxhr.status)
            }
        })(xhr)

        xhr.open("GET", url)
        xhr.send()
    }

    function graphql(query, variables, callback) {
        const url = "https://api.ardaudiothek.de/graphql"
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = (function(myxhr) {
            return function() {
                if (myxhr.readyState !== 4) return

                var data

                try {
                    data = JSON.parse(myxhr.responseText)
                } catch (e) {
                    data = myxhr.responseText
                }

                if (myxhr.status === 200 && data.errors) {
                    console.log("GraphQL errors:", JSON.stringify(data.errors))
                    callback(null, 500)
                    return
                }

                callback(data, myxhr.status)
            }
        })(xhr)

        xhr.open("POST", url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify({ query: query, variables: variables || {} }))
    }
}
