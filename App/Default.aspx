﻿<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="App_Default" %>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
   <title>Pow Wow</title>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0"/>
    <meta name="description" content="Pow Wow allows people to spontaneously create and recruit for activities, interests, and sports around them today." />
    <link rel="icon" type="image/png" href="/img/favicon.png" />
    <link href="/Styles/App.css" rel="stylesheet" type="text/css" />
    <script src="/Scripts/jquery-2.0.3.min.js" type="text/javascript"></script>
    <script src="/Scripts/Helpers.js" type="text/javascript"></script>
    <script src="https://maps.googleapis.com/maps/api/js?v=3.exp&sensor=false"></script>
    <script type="text/javascript">
        var isMobile;
        var currentLat;
        var currentLng;
        var locationResults = [];
        var currentLocation = {};

        $(document).ready(function () {
            var mobParam = getParameterByName("id");
            isMobile = mobilecheck() || tabletCheck() || mobParam == "m";
            if (!isMobile) {
                $("body").removeClass("Mobile");
            }
            else
            {
                //$("#addMap").height($(document).height() - 475);
            }

            if (!$("#FacebookId").val()) {
                var fbInterval = setInterval(function () {
                    if ($("#FacebookId").val()) {
                        clearInterval(fbInterval);
                        navigator.geolocation.getCurrentPosition(LocationReturn);
                    }
                }, 500);
            }

            $("#notificationBtn").click(function () {
                NotificationClick();
            });

            $("#addBtn").click(function () {
                OpenFromBottom("addDiv");
            });

            $("#AddLocation").click(function () {
                $("#locationSearchTextbox").val("");
                OpenFromBottom("locationDiv");
            });

            $("#AddStartTime").click(function () {
                InitClock();
            });

            $("#isPublicBtn").click(function () {
                PublicClick();
            });

            $("#inviteBtn").click(function () {
                OpenFromBottom("inviteDiv");
                Post("GetFriends", { facebookAccessToken: fbAccessToken }, PopulateFriends);
            });

            $("#filterFriendsTextbox").keyup(function () {
                FilterFriends();
            });

            $("#inviteResults").on("click", "div", function () {
                $(this).toggleClass("invited");
            });

            $("#locationSearchTextbox").keyup(function () {
                var search = $("#locationSearchTextbox").val();
                if (search.length < 3)
                    return;

                Post("GetLocations", { searchName: search, latitude: currentLat, longitude: currentLng }, PopulateLocations);
            });
            
        });

        function LocationReturn(position)
        {
            currentLat = position.coords.latitude;
            currentLng = position.coords.longitude;
            LoadEvents();
        }

        function LoadEvents()
        {
            Post("GetEvents", { latitude: currentLat, longitude: currentLng }, PopulateEvents);
        }

        function ReorderEvents(list)
        {
            var goingList = [];
            var invitedList = [];
            var otherList = [];

            var fbId = $("#FacebookId").val();
            for(var i = 0; i < list.length; i++)
            {
                var event = list[i];
                if (event.Going.indexOf(fbId) >= 0)
                    goingList.push(event);
                else if (event.Invited.indexOf(fbId) >= 0)
                    invitedList.push(event);
                else
                    otherList.push(event);
            }

            var eventList = $.merge($.merge(goingList, invitedList), otherList);
            return eventList;
        }

        function PopulateEvents(results)
        {
            var eventList = ReorderEvents(results);

            var fbId = $("#FacebookId").val();
            var html = "";
            for (var i = 0; i < eventList.length; i++) {
                var event = eventList[i];
                var eventHtml = '<div class="event">{img}<div style="float:left;"><span style="color:#4285F4;;">{name}</span><div style="height:4px;"></div>{distance}</div><div style="float:right;">{time}<div style="height:4px;"></div>{going}</div><div style="clear:both;"></div></div>';
                var time = new Date(event.StartTime).toLocaleTimeString().replace(":00", "");
                eventHtml = eventHtml.replace("{name}", event.Name).replace("{distance}", event.Distance).replace("{time}", time).replace("{going}", event.HowManyGoing);
                if (event.Going.indexOf(fbId) >= 0)
                    eventHtml = eventHtml.replace("{img}", '<img class="going" src="https://graph.facebook.com/' + fbId + '/picture" />');
                else if (event.Invited.indexOf(fbId) >= 0)
                    eventHtml = eventHtml.replace("{img}", '<img src="../Img/invited.png" />');
                else if (event.IsPrivate)
                    eventHtml = eventHtml.replace("{img}", '<img src="../Img/lock.png" />');
                else
                    eventHtml = eventHtml.replace("{img}", '<img src="../Img/face' + Math.floor(Math.random() * 8) + '.png" />');

                html += eventHtml;
            }

            $(".content").html(html);
        }

        function SaveClick() {

            $("#addDiv input, #addDiv textarea").removeClass("error");
            var error = false;
            if (!$("#AddName").val()) {
                $("#AddName").addClass("error");
                error = true;
            }
            if (!$("#AddLocation").val()) {
                $("#AddLocation").addClass("error");
                error = true;
            }
            if (!$("#AddStartTime").val()) {
                $("#AddStartTime").addClass("error");
                error = true;
            }
            if (!$("#AddMin").val()) {
                $("#AddMin").addClass("error");
                error = true;
            }
            if (error)
                return;

            var now = new Date();
            var startTime = new Date();
            var time = $("#clockDiv .time").html();
            var hr = +time.substring(0, time.indexOf(":"));
            time = time.substring(time.indexOf(":") + 1);
            var min = +time.substring(0, time.indexOf(" "));
            var AMPM = time.substring(time.length - 2, time.length);
            if (AMPM == "AM" && hr == 12)
                hr = 0;
            if (AMPM == "PM")
                hr += 12;
            startTime.setHours(hr);
            startTime.setMinutes(min);

            if(now > startTime) {
                $("#AddStartTime").addClass("error");
                return;
            }
            var diffMinutes = parseInt((startTime - now)/(60*1000));
            var cutoffDiff = 0;
            if (diffMinutes > 29)
                cutoffDiff = 15;
            if (diffMinutes > 59)
                cutoffDiff = 30;
            if(diffMinutes > 179)
                cutoffDiff = 60;

            var MS_PER_MINUTE = 60000;
            var cutoffTime = new Date(startTime - cutoffDiff * MS_PER_MINUTE);

            var invited = "";
            $("#invitedFriends div").each(function () {
                var fbId = $(this).attr("facebookid");
                if (fbId)
                    invited += !invited ? fbId : "|" + fbId;
            })

            var max = +$("#AddMax").val();
            if (max) max++;

            var event = { Name: $("#AddName").val(), EventDescription: $("#AddDetails").val(), LocationName: currentLocation.Name,
                LocationAddress: currentLocation.Address, LocationLatitude: currentLocation.Latitude, LocationLongitude: currentLocation.Longitude,
                IsPrivate: $("#isPublicBtn .selected").html() == "Private", MinParticipants: +$("#AddMin").val() + 1, MaxParticipants: max, 
                StartTime: startTime, CutoffTime: cutoffTime, Invited:invited, Going: currentUser.FacebookId + ":" + currentUser.FirstName };

            var success = (function() {
                LoadEvents();
                CloseToBottom("addDiv");
            });
            Post("SaveEvent", { evt: event }, success);

            CloseToBottom("addDiv");
        }

        function PublicClick() {
            alert("Pow Wow currently does not have enough members near you to create public events. Invite your friends to enable public events.");

            //var marginLeft = $(".pillBtn .slider").css("margin-left") == "0px" ? "44%" : "0px";
            //$(".pillBtn .slider").animate({ "margin-left": marginLeft }, 350, function () {
            //    $(".pillBtn div").not(".slider").toggleClass("selected");
            //});
        }

        function PopulateLocations(locations) {
            locationResults = locations;
            var html = "";
            if (locationResults.length == 1 && !locationResults[0].Name) {
                html = '<div onclick="AddLocation(-1);" style="border:none;" ><span style="font-weight:bold;color:#4285F4;">Just use "' + $("#locationSearchTextbox").val() + '"</span></div>';
            }
            else {
                for (var i = 0; i < locationResults.length; i++) {
                    var location = locationResults[i];
                    var locationHtml = '<div onclick="AddLocation(' + i + ');" ><span style="font-weight:bold;">{Name}</span><div></div>{Address}</div>';
                    html += locationHtml.replace("{Name}", location.Name).replace("{Address}", location.Address);
                }
            }
            $("#locationResults").html(html);
        }

        function AddLocation(index) {
            if (index == -1) {
                var address = $("#locationSearchTextbox").val() + ", " + locationResults[0].Address;
                console.log(address);
                var geocoder = new google.maps.Geocoder();
                geocoder.geocode({ 'address': address }, function (results, status) {
                    if (status == google.maps.GeocoderStatus.OK) {
                        currentLocation = { Name: $("#locationSearchTextbox").val(), Address: $("#locationSearchTextbox").val(), Latitude: results[0].geometry.location.lat(), Longitude: results[0].geometry.location.lng() };
                        PlotMap(currentLocation.Name, currentLocation.Latitude, currentLocation.Longitude);
                        $("#AddLocation").val(currentLocation.Name);
                    }
                });
            }
            else {
                currentLocation = locationResults[index];
                PlotMap(currentLocation.Name, currentLocation.Latitude, currentLocation.Longitude);
                $("#AddLocation").val(currentLocation.Name);
            }

            CloseToBottom("locationDiv");
        }

        function PlotMap(name, lat, lng) {
            var latLng = new google.maps.LatLng(lat, lng);
            var mapOptions = {
                zoom: 15,
                center: latLng,
                mapTypeId: google.maps.MapTypeId.ROADMAP
            }

            var map = new google.maps.Map(document.getElementById('addMap'), mapOptions);
            var marker = new google.maps.Marker({
                position: latLng,
                map: map,
                title: name
            });
        }

        function PopulateFriends(friendList) {

            var html = "<div style='color:white;background:#AAAAAA;'>Friends</div>";
            for (var i = 0; i < friendList.length; i++) {
                var friend = friendList[i];
                html += '<div facebookId="' + friend.FacebookId + '"><span>' + friend.Name + '</span><img src="/Img/check.png" /></div>';
            }
            $("#inviteResults").html(html);
        }

        function FilterFriends() {
            var filter = $("#filterFriendsTextbox").val();
            $("#inviteResults div").not(":eq(0)").each(function () {
                if (!filter || $(this).html().toLowerCase().indexOf(filter.toLowerCase()) >= 0)
                    $(this).show();
                else
                    $(this).hide();
            });
        }

        function AddInvites() {
            var html = "";
            $("#inviteResults div.invited").each(function () {
                var fbId = $(this).attr("facebookId");
                var name = $(this).find("span").html();
                if (name.indexOf(" ") >= 0)
                    name = name.substring(0, name.indexOf(" "));
                html += "<div facebookId='" + fbId + "' ><img src='https://graph.facebook.com/" + fbId + "/picture' /><div>" + name + "</div></div>";
            });

            $("#invitedFriends").html(html);
            CloseToBottom("inviteDiv");
        }

        function NotificationClick() {
            console.log($("#notificationDiv").is(':visible'));
            if ($("#notificationDiv").is(':visible'))
                CloseNotification();
            else
                LoadNotifications();
        }

        function LoadNotifications() {
            Post("GetNotifications", { facebookId: $("#FacebookId").val() }, PopulateNotifications);
        }

        function PopulateNotifications(results) {
            var html = "";
            for(var i = 0; i < results.length; i++)
            {
                var notification = results[i];
                var notificationHtml = '<div><span style="font-weight:bold;">{Message}</span><div></div>{SinceSent}</div>';
                notificationHtml = notificationHtml.replace("{Message}", notification.Message).replace("{SinceSent}", notification.SinceSent);
                html += notificationHtml;
            }

            $("#notificationDiv").html(html);
            OpenNotification();
        }

        function OpenNotification() {
            $("#notificationDiv").show();
            $("#notificationDiv").animate({ left: "25%" }, 350);
        }

        function CloseNotification() {
            $("#notificationDiv").animate({ left: "100%" }, 350, function() {
                $("#notificationDiv").hide();
            });
        }
    </script>
    <script type="text/javascript">
        var currentUser;
        var fbAccessToken;

        window.fbAsyncInit = function () {
            FB.init({
                appId: '397533583786525', // App ID
                status: true, // check login status
                cookie: true, // enable cookies to allow the server to access the session
                xfbml: true  // parse XFBML
            });

            FB.getLoginStatus(function (response) {
                if (response.status === 'connected') {
                    // the user is logged in and has authenticated your
                    // app, and response.authResponse supplies
                    // the user's ID, a valid access token, a signed
                    // request, and the time the access token 
                    // and signed request each expire
                    var uid = response.authResponse.userID;
                    $("#FacebookId").val(uid);
                    fbAccessToken = response.authResponse.accessToken;

                    var success = (function (results) {
                        currentUser = results;
                    });
                    Post("GetUser", { facebookAccessToken: fbAccessToken }, success);

                } else {
                    window.location = "../";
                }
            });
        };

        // Load the SDK Asynchronously
        (function (d) {
            var js, id = 'facebook-jssdk', ref = d.getElementsByTagName('script')[0];
            if (d.getElementById(id)) { return; }
            js = d.createElement('script'); js.id = id; js.async = true;
            js.src = "//connect.facebook.net/en_US/all.js";
            ref.parentNode.insertBefore(js, ref);
        }(document));
</script>
    <script type="text/javascript">
        $(document).ready(function () {
            $("#clockCircle").on("click", "div", function () {
                $("#clockCircle div").removeClass("selected");
                $(this).addClass("selected");
                if ($(this).hasClass("hour")) {
                    HourClicked($(this).html());
                }
                else {
                    var time = $("#clockDiv .time").html();
                    var hr = time.substring(0, time.indexOf(":"));
                    var min = $(this).html();
                    if (min == "5")
                        min = "05";
                    var AMPM = time.substring(time.indexOf(" ") + 1);
                    time = hr + ":" + min + " " + AMPM;
                    $("#clockDiv .time").html(time);
                    $("#AddStartTime").val(time);
                    $("#clockDiv").fadeOut();
                    $(".modal-backdrop").fadeOut();
                }
            });

            $(".ampm").click(function () {
                $(".ampm").removeClass("selected");
                $(this).addClass("selected");

                var time = $("#clockDiv .time").html();
                time = time.substring(0, time.indexOf(" ") + 1);
                time += $(this).html();
                $("#clockDiv .time").html(time)
            });
        });

        function InitClock() {
            $(".modal-backdrop").show();
            $("#clockDiv").show();
            $("#clockCircle").html("");
            if (!$("#clockDiv .time").html().length) {
                var date = new Date;
                var min = date.getMinutes();
                if (min < 10)
                    min = "0" + min;
                var hr = date.getHours();
                var AMPM = "AM";
                if (hr > 11)
                    AMPM = "PM";
                if (hr > 12)
                    hr -= 12;
                if (hr == 0)
                    hr = 12;

                $(".ampm").each(function () {
                    if ($(this).html() == AMPM)
                        $(this).addClass("selected");
                });

                $("#clockDiv .time").html(hr + ":" + min + " " + AMPM);
            }
            else {
                var time = $("#clockDiv .time").html();
                var hr = time.substring(0, time.indexOf(":"));
            }

            var wd = $("#clockCircle").width();
            $("#clockCircle").height(wd * .8);

            var radius = (wd / 2) * .7;
            var html = "";
            var centerX = wd / 2;
            var centerY = wd / 2 + 60;
            for (var i = 1; i < 13; i++) {
                var x = Math.cos(2 * Math.PI * ((i - 3) / 12)) * radius + centerX;
                var y = Math.sin(2 * Math.PI * ((i - 3) / 12)) * radius + centerY;
                if (i == hr) {
                    html += '<div class="selected hour" style="position:absolute;left:' + x + 'px;top:' + y + 'px;">' + i + '</div>';
                }
                else {
                    html += '<div class="hour" style="position:absolute;left:' + x + 'px;top:' + y + 'px;">' + i + '</div>';
                }

            }
            $("#clockCircle").append(html);
        }

        function HourClicked(hr) {

            var time = $("#clockDiv .time").html();
            time = time.substring(time.indexOf(":"));
            var min = +time.substring(1, time.indexOf(" "));
            console.log(min);
            time = hr + time;
            $("#clockDiv .time").html(time);

            var wd = $("#clockCircle").width();
            $("#clockCircle").fadeOut("slow", function () {
                var radius = (wd / 2) * .7;
                var html = "";
                var centerX = wd / 2;
                var centerY = wd / 2 + 60;
                for (var i = 0; i < 12; i++) {
                    var x = Math.cos(2 * Math.PI * ((i - 3) / 12)) * radius + centerX;
                    var y = Math.sin(2 * Math.PI * ((i - 3) / 12)) * radius + centerY;
                    var val = i == 0 ? "00" : (i * 5);
                    if ((i - 1) * 5 < min && i * 5 >= min)
                        html += '<div class="selected" style="position:absolute;left:' + x + 'px;top:' + y + 'px;">' + val + '</div>';
                    else
                        html += '<div style="position:absolute;left:' + x + 'px;top:' + y + 'px;">' + val + '</div>';

                }
                $("#clockCircle").html(html);
                $("#clockCircle").fadeIn("slow");
            });

        }

        function DrawLine(x1, y1, x2, y2) {

            if (y1 < y2) {
                var pom = y1;
                y1 = y2;
                y2 = pom;
                pom = x1;
                x1 = x2;
                x2 = pom;
            }

            var a = Math.abs(x1 - x2);
            var b = Math.abs(y1 - y2);
            var c;
            var sx = (x1 + x2) / 2;
            var sy = (y1 + y2) / 2;
            var width = Math.sqrt(a * a + b * b);
            var x = sx - width / 2;
            var y = sy;

            a = width / 2;
            c = Math.abs(sx - x);
            b = Math.sqrt(Math.abs(x1 - x) * Math.abs(x1 - x) + Math.abs(y1 - y) * Math.abs(y1 - y));

            var cosb = (b * b - a * a - c * c) / (2 * a * c);
            var rad = Math.acos(cosb);
            var deg = (rad * 180) / Math.PI

            htmlns = "http://www.w3.org/1999/xhtml";
            div = document.createElementNS(htmlns, "div");
            div.setAttribute('style', 'border:1px solid #4285F4;width:' + width + 'px;height:0px;-moz-transform:rotate(' + deg + 'deg);-webkit-transform:rotate(' + deg + 'deg);position:absolute;top:' + y + 'px;left:' + x + 'px;');

            document.getElementById("clockDiv").appendChild(div);

        }
    </script>

</head>
<body class="Mobile">
    <form id="form1" runat="server">
        <div id="fb-root"></div>
        <input type="hidden" id="FacebookId" runat="server" />
        <div class="modal-backdrop"></div>
        <div class="header">
            <div>
                <img class="title" src="/Img/title.png" />
                <img id="notificationBtn" src="/Img/bell.png" />
            </div>
        </div>
        <div class="content">
            <%--<div class="event">
                <img class="going" src="https://graph.facebook.com/10106153174286280/picture" />
                <div style="float:left;"><span style="color:#4285F4;;">Test</span><div style="height:4px;"></div>2 miles away</div>
                <div style="float:right;">11:37 PM<div style="height:4px;"></div>1 of 3</div>
            </div>--%>
        </div>
        <img id="addBtn" src="../Img/add.png" />
        <div id="addDiv">
            <a onclick="CloseToBottom('addDiv');" style="position: absolute; left:5%;top:20px;color:#4285F4;">Cancel</a>
            <div style="font-size:1.1em;margin-top:18px;text-align: center;">Create Event</div>
            <a onclick="SaveClick();" style="position: absolute; right:5%;top:20px;color:#4285F4;">Create</a>
            <input id="AddName" type="text" placeholder="What do you want to do?" style="margin:12px 0;" />
            <textarea id="AddDetails" rows="4" placeholder="Details"></textarea>
            <input id="AddLocation" type="text" placeholder="Location" style="width:48%;float:left;" />
            <input id="AddStartTime" type="text" placeholder="Start Time" readonly="readonly" style="width:32%;float:right;" />
            <div style="float:left;margin:16px 0;">Other People:</div>
            <input id="AddMax" type="number" placeholder="Max" style="width:20%;float:right;margin-left:12px;" />
            <input id="AddMin" type="number" placeholder="Min" style="width:20%;float:right;" />
            <div id="isPublicBtn" class="pillBtn" style="clear:both;">
                <div class="slider"></div>
                <div style="margin: -25px 0 0 18%;float:left;">Public</div>
                <div style="margin: -25px 18% 0 0;float:right;" class="selected">Private</div>
            </div>
            <div id="inviteBtn" style="text-align:center;color:#4285F4;margin: 16px 0 8px;">Invite Friends</div>
            <div id="invitedFriends"></div>
            <div id="addMap"></div>
        </div>
        <div id="locationDiv">
            <a onclick="CloseToBottom('locationDiv');" style="position: absolute; left:5%;top:20px;color:#4285F4;">Cancel</a>
            <div style="font-size:1.1em;margin-top:18px;text-align: center;">Add Location</div>
            <input id="locationSearchTextbox" type="text" placeholder="Search" style="margin:12px 0;" />
            <div id="locationResults"></div>
        </div>
        <div id="inviteDiv">
            <a onclick="CloseToBottom('inviteDiv');" style="position: absolute; left:5%;top:20px;color:#4285F4;">Cancel</a>
            <div style="font-size:1.1em;margin-top:18px;text-align: center;">Recipients</div>
            <a onclick="AddInvites();" style="position: absolute; right:5%;top:20px;color:#4285F4;">Add</a>
            <input id="filterFriendsTextbox" type="text" placeholder="Search" style="margin:12px 0;" />
            <div id="inviteResults"></div>
        </div>
        <div id="notificationDiv"></div>
        <div id="clockDiv">
            <div class="time"></div>
            <div id="clockCircle"></div>
            <div class="ampm" style="float:left;">AM</div>
            <div class="ampm" style="float:right;">PM</div>
            <div onclick='$("#clockDiv").fadeOut();$(".modal-backdrop").fadeOut();' style="position:absolute;bottom: 0;left:0;height: 36px;width:100%;border-top: 1px solid #ccc;">
                <div style="text-align:center;color:#4285F4;margin-top:9px;">Cancel</div>
            </div>
        </div>
    </form>
</body>
</html>
