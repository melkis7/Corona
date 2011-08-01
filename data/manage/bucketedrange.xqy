(:
Copyright 2011 MarkLogic Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
:)

xquery version "1.0-ml";

import module namespace manage="http://marklogic.com/mljson/manage" at "../lib/manage.xqy";
import module namespace common="http://marklogic.com/mljson/common" at "../lib/common.xqy";
import module namespace json="http://marklogic.com/json" at "../lib/json.xqy";

import module namespace rest="http://marklogic.com/appservices/rest" at "../lib/rest/rest.xqy";
import module namespace endpoints="http://marklogic.com/mljson/endpoints" at "/config/endpoints.xqy";
import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

declare option xdmp:mapping "false";


let $params := rest:process-request(endpoints:request("/data/manage/bucketedrange.xqy"))
let $name := map:get($params, "name")
let $requestMethod := xdmp:get-request-method()

let $config := admin:get-configuration()
let $existing := manage:getBucketedRange($name)

return
    if($requestMethod = "GET")
    then
        if(exists($existing))
        then json:xmlToJSON($existing)
        else common:error(404, "Bucketed range index not found", "json")

    else if($requestMethod = "POST")
    then
        let $key := map:get($params, "key")
        let $element := map:get($params, "element")
        let $attribute := map:get($params, "element")
        let $type := map:get($params, "type")
        let $bucketString := map:get($params, "buckets")
        let $buckets :=
            (: doesn't look like the server supports negative lookbehind, hence this sad hack :)
            let $bucketString := replace($bucketString, "\\\|", "____________PIPE____________")
            let $bucketString := replace($bucketString, "\\\\", "\\")

            for $bit at $pos in tokenize($bucketString, "\|")
            let $bit := replace($bit, "____________PIPE____________", "|")
            return 
                if($pos mod 2)
                then <label>{ $bit }</label>
                else <boundary>{ $bit }</boundary>

        let $autoBucket := map:get($params, "autoBucket")
        let $startingAt := map:get($params, "startingAt")
        let $stoppingAt := map:get($params, "stoppingAt")
        return

        if((empty($key) and empty($element)) or (exists($key) and exists($element)))
        then common:error(500, "Must supply either a JSON key or XML element name", "json")
        else if(exists($attribute) and empty($element))
        then common:error(500, "Must supply an XML element along with an XML attribute", "json")
        else if(exists($key) and not($type = ("string", "date", "number")))
        then common:error(500, "Valid JSON types are: string, date and number", "json")
        else if(exists($element) and not($type = ("int", "unsignedInt", "long", "unsignedLong", "float", "double", "decimal", "dateTime", "time", "date", "gYearMonth", "gYear", "gMonth", "gDay", "yearMonthDuration", "dayTimeDuration", "string", "anyURI")))
        then common:error(500, "Valid XML types are: int, unsignedInt, long, unsignedLong, float, double, decimal, dateTime, time, date, gYearMonth, gYear, gMonth, gDay, yearMonthDuration, dayTimeDuration, string and anyURI", "json")
        else if(exists(manage:validateIndexName($name)))
        then common:error(500, manage:validateIndexName($name), "json")
        else if(exists($existing))
        then common:error(500, "A buckted range index with this configuration already exists", "json")
        else if(exists($buckets))
        then
            if(exists($key))
            then manage:createJSONBucketedRange($name, $key, $type, $buckets, $config)
            else if(exists($element) and exists($attribute))
            then manage:createXMLAttributeBucketedRange($name, $element, $attribute, $type, $buckets, $config)
            else if(exists($element) and empty($attribute))
            then manage:createXMLElementBucketedRange($name, $element, $type, $buckets, $config)
            else ()
        else if(exists($autoBucket) and exists($startingAt))
        then
            if(exists($key))
            then manage:createJSONAutoBucketedRange($name, $key, $type, $autoBucket, $startingAt, $stoppingAt, $config)
            else if(exists($element) and exists($attribute))
            then manage:createXMLAttributeAutoBucketedRange($name, $element, $attribute, $type, $autoBucket, $startingAt, $stoppingAt, $config)
            else if(exists($element) and empty($attribute))
            then manage:createXMLElementAutoBucketedRange($name, $element, $type, $autoBucket, $startingAt, $stoppingAt, $config)
            else ()
        (: XXX - throw an error :)
        else ()

    else if($requestMethod = "DELETE")
    then
        if(exists($existing))
        then manage:deleteBucketedRange($name, $config)
        else common:error(404, "Bucketed range index not found", "json")
    else ()

