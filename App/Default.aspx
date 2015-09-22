﻿<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="App_Default" %>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
   <title>Pow Wow</title>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0"/>
    <meta name="description" content="Pow Wow allows people to spontaneously create and recruit for activities, interests, and sports around them today." />
    <link rel="icon" type="image/png" href="/img/favicon.png" />
    <link href="/Styles/App.css?i=4" rel="stylesheet" type="text/css" />
    <link href="/Styles/NonMobileApp.css" rel="stylesheet" type="text/css" />
    <script src="/Scripts/jquery-2.0.3.min.js" type="text/javascript"></script>
    <script src="/Scripts/jquery.touchSwipe.min.js" type="text/javascript"></script>
    <script src="/Scripts/Helpers.js" type="text/javascript"></script>
    <script src="https://maps.googleapis.com/maps/api/js?v=3.exp&sensor=false"></script>
    <script type="text/javascript">
        var isMobile;
        var isiOS;
        var isAndroid;
        var currentLat;
        var currentLng;
        var currentEvent = {};
        var currentUser;

        $(document).ready(function () {
            Init();

            var scrollTimer;
            $(".content").scroll(function () {
                if (scrollTimer) {
                    clearTimeout(scrollTimer);
                }
                scrollTimer = setTimeout(function () {
                    if ($(".content").scrollTop() < 15) {
                        ShowLoading();
                        LoadEvents();
                    }
                    else if ($(".content").scrollTop() < 90) {
                        $(".content").animate({ scrollTop: "90" }, 350);
                    }
                }, 100);
            });

            $(".title").click(function () {
                CloseMenu();
                CloseGroups();
            });

            $(".content, #groupEvents").on("click", ".event", function () {
                if (!currentUser || !currentUser.Id) {
                    OpenLogin();
                    return;
                }

                var eventId = $(this).attr("eventid");
                Post("GetEvent", { id: eventId }, OpenEventDetails);
            });

            $(".content").on("click", ".group", function () {
                if (!currentUser || !currentUser.Id) {
                    OpenLogin();
                    return;
                }

                var groupId = $(this).attr("groupid");
                GetGroup(groupId);
            });

            $(".screenHeader .backArrow").click(function () {
                $(this).closest(".screen").hide();
            });

            $("#addDiv .backArrow").click(function () {
                LoadEvents();
            });

            $("#detailsDiv .backArrow").click(function () {
                LoadEvents();
            });
        });

        function Init()
        {
            ShowLoading();
            if ($(window).height() > 550)
                $(".content div").css("min-height", ($(window).height() - 135) + "px");

            isiOS = getParameterByName("OS") == "iOS";
            isAndroid = getParameterByName("OS") == "Android";

            var mobParam = getParameterByName("id");
            isMobile = mobilecheck() || tabletCheck() || mobParam == "m";

            if (isiOS || isAndroid || isMobile) {

                currentUser = {};
                var fbAccessToken = getParameterByName("fbAccessToken");
                var deviceId = getParameterByName("deviceId");
                var pushDeviceToken = getParameterByName("pushDeviceToken");
                if(fbAccessToken || pushDeviceToken)
                    Post("LoginUser", { facebookAccessToken: fbAccessToken, deviceId: deviceId, pushDeviceToken: pushDeviceToken, email: "", password: "" }, LoginSuccess);

                currentLat = +getParameterByName("lat");
                currentLng = +getParameterByName("lng");

                if (currentLat && currentLng)
                    LoadEvents();
                //else
                //    navigator.geolocation.getCurrentPosition(LatLngReturn);

            }

            if (!isMobile) {
                $("body").addClass("NonMobile");
            }
            if (isiOS) {
                $("body").addClass("ios");
            }
        }

        function LoginSuccess(results) {
            currentUser = results;

            if (currentUser && currentUser.Latitude && currentUser.Longitude)
                ReceiveLocation(currentUser.Latitude, currentUser.Longitude);
            if (currentUser)
                LoadMyGroups();
        }

        function ReceiveLocation(lat, lng)
        {
            if (!(currentLat && currentLng && Math.abs(currentLat - (+lat)) < 1 && Math.abs(currentLng - (+lng)) < 1))
            {
                currentLat = +lat;
                currentLng = +lng;
                ShowLoading();
                LoadEvents();
            }

            if(currentUser && currentUser.Id)
            {
                currentUser.Latitude = currentLat;
                currentUser.Longitude = currentLng;
                Post("SaveUser", { user: currentUser });
            }
        }

        function GoToEvent(referenceId)
        {
            Post("GetEventByReference", { referenceId: referenceId }, OpenEventDetails);
            $("#detailsDiv").show();
            $("#detailsDiv").css({ top: "0" });
        }

        function LatLngReturn(position)
        {
            currentLat = position.coords.latitude;
            currentLng = position.coords.longitude;
            MessageBox(currentLat + "," + currentLng);
            LoadEvents();
        }

        function LoadEvents()
        {
            Post("GetEvents", { latitude: currentLat, longitude: currentLng, user: currentUser }, PopulateEvents);
        }

        function PopulateEvents(results)
        {
            var html = SetLocalTimes(results);

            $(".content div").html(html);
            $(".content").scrollTop(90);

            var nameMaxWidth = screen.width - 160;
            $(".content div.name").css("max-width", nameMaxWidth);
            HideLoading();
        }

        function SetLocalTimes(html)
        {
            while(html.indexOf("{{") >= 0)
            {
                var beginIdx = html.indexOf("{{");
                var endIdx = html.indexOf("}}");
                var time = html.substring(beginIdx + 2, endIdx);
                var localTime = ToLocalTime(time);
                html = html.substring(0, beginIdx) + localTime + html.substring(endIdx + 2);
            }
            return html;
        }
    </script>

    <!-- Add / Edit Event -->
    <script type="text/javascript">
        $(document).ready(function () {
            $("#addBtn").click(function () {
                OpenAdd();
            });

            $("#addDiv .bottomBtn").click(function () {
                SaveEvent();
            });

            $("#deleteEventBtn").click(function () {
                ActionMessageBox("This will delete this event. Continue?", DeleteEvent);
            });

            $("#AddGroupName").click(function () {
                $(".modal-backdrop").show();
                $("#addGroupDiv").show();
            });

            $("#addGroupsResultsDiv").on("click", "div", function () {
                var groupId = $(this).attr("groupid");
                if (!groupId)
                    return;

                var name = $(this).find("div").html();
                $("#AddGroupName").val(name);
                currentGroup.Id = groupId;
                currentGroup.Name = name;
                CloseAddGroup();

            });

            $("#addGroupDiv .smallBottomBtn").click(function () {
                CloseAddGroup();
            });

            $("#addFromGroupBtn").click(function () {
                var groupId = currentGroup.Id;
                OpenAdd();
                var name = $("#groupDetailsDiv .screenTitle").html();
                $("#AddGroupName").val(name);
                currentGroup.Id = groupId;
                currentGroup.Name = name;
            });
        });

        function OpenAdd(isEdit) {
            if (!currentUser || !currentUser.Id) {
                OpenLogin();
                return;
            }

            $("#addDiv").show();
            $("#addDiv input").removeClass("error");
            if (!isEdit) {
                $("#addDiv .screenTitle").html("Create Event");
                $("#addDiv .bottomBtn").html("Create");
                $("#addDiv .bottomBtn").html("Create");
                $("#addDiv input, #addDiv textarea").val("");
                $("#addDiv .invitedFriendsScroll").html("");
                $("#AddMap").css("height", "165px").hide();
                $("#addDiv .invitedFriends").show();
                $("#deleteEventBtn").hide();
                currentEvent = {};
                currentLocation = {};
                currentGroup = {};
            }
            else {
                $("#addDiv .screenTitle").html("Edit Event");
                $("#addDiv .bottomBtn").html("Save");
                $("#AddName").val(currentEvent.Name);
                $("#addDiv .bottomBtn").html("Save");
                $("#AddDetails").val(currentEvent.Description);
                $("#AddLocation").val(currentEvent.LocationName);
                currentLocation = { Name: currentEvent.LocationName, Address: currentEvent.LocationAddress, Latitude: currentEvent.LocationLatitude, Longitude: currentEvent.LocationLongitude };
                $("#AddStartTime").val(ToLocalTime(currentEvent.StartTime));
                var min = currentEvent.MinParticipants > 1 ? currentEvent.MinParticipants : "";
                $("#AddMin").val(min);
                var max = currentEvent.MaxParticipants ? currentEvent.MaxParticipants : "";
                $("#AddMax").val(max);
                currentGroup = { Id: currentEvent.GroupId };
                $("#addGroupsResultsDiv div").each(function () {
                    if($(this).attr("groupid") == currentEvent.GroupId)
                        $("#AddGroupName").val($(this).find("div").html());
                });
                
                $("#AddMap").css("height", "135px");
                PlotMap("AddMap", currentEvent.LocationName, currentEvent.LocationLatitude, currentEvent.LocationLongitude);
                $("#deleteEventBtn").show();
            }
        }

        function SaveEvent() {

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
            if (error)
                return;


            var event = GetCreateEvent();

            if (new Date() > event.StartTime) {
                $("#AddStartTime").addClass("error");
                return;
            }

            var success = (function (event) {
                LoadEvents();
                $("#addDiv").hide();

                if (currentEvent.Id) {
                    currentEvent = event;
                    OpenEventDetails(currentEvent);
                }
                else if (event.GroupId) {
                    GetGroup(event.GroupId);

                    var alert = "New event posted to your group " + currentGroup.Name + ".";
                    var messageText = "";
                    Post("SendMessageToGroup", { groupId: event.GroupId, alert: alert, messageText: messageText, userId: currentUser.Id });
                }
            });
            Post("SaveEvent", { evt: event }, success);

            $("#addDiv").hide();
        }

        function GetCreateEvent() {
            var startTime = "";
            if ($("#AddStartTime").val()) {
                var now = new Date();
                startTime = new Date();
                var time = $("#AddStartTime").val();
                var hr = +time.substring(0, time.indexOf(":"));
                time = time.substring(time.indexOf(":") + 1);
                var min = +time.substring(0, time.indexOf(" "));
                var AMPM = time.substring(time.length - 2, time.length);
                if (AMPM == "AM" && hr == 12)
                    hr = 0;
                if (AMPM == "PM" && hr != 12)
                    hr += 12;
                startTime.setHours(hr);
                startTime.setMinutes(min);
                startTime.setSeconds(0);
            }

            var max = +$("#AddMax").val();
            var min = +$("#AddMin").val();

            var groupId = currentGroup.Id;

            var event = {
                Name: $("#AddName").val(), Description: $("#AddDetails").val(), GroupId: groupId, LocationName: currentLocation.Name,
                LocationAddress: currentLocation.Address, LocationLatitude: currentLocation.Latitude, LocationLongitude: currentLocation.Longitude,
                MinParticipants: min, MaxParticipants: max, StartTime: startTime,
                NotificationMessage: "Created: " + $("#AddName").val(), UserId: currentUser.Id
            };

            if (currentEvent.Id) {
                event.Id = currentEvent.Id;
                event.NotificationMessage = "";
                event.UserId = "";
                event.Going = currentEvent.Going;
            }

            return event;
        }

        function CloseAddGroup() {
            $("#addGroupDiv").fadeOut();
            $(".modal-backdrop").fadeOut();
        }

        function DeleteEvent() {
            var success = function () {
                $("#addDiv").hide();
                $("#detailsDiv").hide();
                LoadEvents();
            }
            Post("DeleteEvent", { evt: currentEvent }, success);
        }

    </script>

    <!-- Details -->
    <script type="text/javascript">
        $(document).ready(function () {
            $("#detailsDiv .detailMenuBtn").click(function () {
                setTimeout(function () { $("#detailsEditBtn").show() }, 50);
            });

            $("#detailsDiv").click(function () {
                $("#detailsEditBtn").hide();
            });

            $("#detailsDiv .detailMenuBtn").click(function () {
                $("#detailsEditBtn").show();
            });

            $("#detailsEditBtn").click(function () {
                OpenAdd(true);
            });

            $("#joinBtn").click(function () {
                if (!IsGoing(currentEvent.Going, currentUser.Id))
                    JoinEvent();
                else
                    ActionMessageBox("Unjoin " + currentEvent.Name + "?", UnjoinEvent, null, "Yes", "No");
            });
        });

        function OpenEventDetails(event) {

            currentEvent = event;
            $("#detailsDiv").show();
            if (event.GroupId) {
                $("#detailsDiv").removeClass("nonGroup");
                $("#detailsLogo").show().attr("src", currentGroup.PictureUrl);
            }
            else {
                $("#detailsDiv").addClass("nonGroup");
                $("#detailsLogo").hide();
            }

            $("#detailsDiv .screenTitle").html(event.Name);
            var subheaderHtml = ToLocalTime(event.StartTime) + " - " + event.LocationName;
            $("#detailsDiv #detailsInfo").html(subheaderHtml);

            var descHtml = event.Description;
            if (descHtml.length > 200) {
                descHtml = descHtml.substring(0, 200) + " ... ";
                descHtml += "<a class='readMore'>Read More</a>";
            }

            $("#detailsDescription").html(descHtml);

            UpdateDetailsGoing(event);

            setTimeout(function () {
                var mapHt = $(window).height() - $("#detailsMap").offset().top - 20;
                if (mapHt < 165)
                    mapHt = 165;
                $("#detailsMap").css("height", mapHt + "px");
                PlotMap("detailsMap", event.LocationName, event.LocationLatitude, event.LocationLongitude);
            }, 400);

            if (IsGoing(event.Going, currentUser.Id)) {
                $("#joinBtn").html("GOING");
                $("#joinBtn").addClass("selected");
            }
            else {
                $("#joinBtn").html("+ JOIN EVENT");
                $("#joinBtn").removeClass("selected");
            }
            
            if (IsAdmin(event.Going, currentUser.Id))
                $("#detailsDiv .detailMenuBtn").show();
            else
                $("#detailsDiv .detailMenuBtn").hide();

            var messageSuccess = function (messages) {
                $(messages).each(function () {
                    if (this.Seconds < 60 * 30)
                        $(".messageBtn").attr("src", "/Img/newmessage.png");
                });
            }
            $(".messageBtn").attr("src", "/Img/message.png");
            Post("GetMessages", { eventId: currentEvent.Id }, messageSuccess);
        }

        function UpdateDetailsGoing(event) {

            var howMany = "Going " + event.Going.length;
            if (HowManyGoing(event))
                howMany += " (" + HowManyGoing(event) + ")";
            $("#detailsHowMany").html(howMany);

            var goingHtml = "";
            for (var i = 0; i < event.Going.length; i++) {
                var user = event.Going[i];
                if(user.FacebookId) {
                    var src = "https://graph.facebook.com/" + user.FacebookId + "/picture";
                    goingHtml += "<div><img src='" + src + "' /><div class='goingIcon icon'><img src='/Img/greenCheck.png' /></div><div>" + user.FirstName + "</div></div>";
                }
                else {
                    var src = "/Img/face" + Math.floor(Math.random() * 8) + ".png";
                    goingHtml += "<div class='nonFb'><img src='" + src + "' /><div class='goingIcon icon'><img src='/Img/greenCheck.png' /></div><div>" + user.FirstName + "</div></div>";
                }

            }
            for (var i = event.Going.length; i < event.MaxParticipants; i++) {
                goingHtml += "<div class='nonFb'><img src='/Img/grayface" + Math.floor(Math.random() * 8) + ".png' /><div>Open</div></div>";
            }
            var notGoing = event.MaxParticipants ? (event.MaxParticipants - event.Going.length) * 64 : 0;
            var width = notGoing + (event.Going.length * 70) + 10;
            $("#detailsInvitedFriends .invitedFriendsScroll").css("width", width + "px");

            $("#detailsInvitedFriends .invitedFriendsScroll").html(goingHtml);
        }

        function HowManyGoing(event)
        {
            var howManyGoing = "";
            if (event.MinParticipants > 1 && event.MaxParticipants > 0)
                howManyGoing = "Min: " + event.MinParticipants + " Max: " + event.MaxParticipants;
            else if (event.MinParticipants > 1)
                howManyGoing = "Min: " + event.MinParticipants;
            else if (event.MaxParticipants > 0)
                "Max: " + event.MaxParticipants;

            return howManyGoing;
        }

        function JoinEvent() {
            if (!currentUser || !currentUser.Id) {
                OpenLogin();
                return;
            }

            $("#joinBtn").html("GOING");
            $("#joinBtn").addClass("selected");

            currentEvent.NotificationMessage = "Joined: " + currentEvent.Name;
            currentEvent.UserId = currentUser.Id;
            var going = { EventId: currentEvent.Id, UserId: currentUser.Id, FacebookId: currentUser.FacebookId, FirstName: currentUser.FirstName, IsAdmin: false };
            currentEvent.Going.push(going);
            UpdateDetailsGoing(currentEvent);

            var success = function (results) {
                if (currentEvent.GroupId)
                    GetGroup(currentEvent.GroupId);
                LoadEvents()
            };

            Post("JoinEvent", { evt: currentEvent }, success);
        }

        function UnjoinEvent()
        {
            $("#joinBtn").html("+ JOIN EVENT");
            $("#joinBtn").removeClass("selected");

            currentEvent.NotificationMessage = "Unjoined: " + currentEvent.Name;
            currentEvent.UserId = currentUser.Id;
            RemoveByUserId(currentEvent.Going, currentUser.Id);
            UpdateDetailsGoing(currentEvent);

            var success = function (results) {
                if (currentEvent.GroupId)
                    GetGroup(currentEvent.GroupId);
                LoadEvents()
            };

            Post("UnjoinEvent", { evt: currentEvent }, success);
        }

    </script>

    <!-- Login -->
    <script type="text/javascript">
        $(document).ready(function () {
            $("#loginSignupEmailPlaceholder").click(function () {
                $("#loginSignupEmailTextBox").focus();
            });

            $(".loginSignupHeader .backarrow").click(function () {
                $("#loginSignupDiv").hide();
            });

            $("#loginSignupEmailTextBox").keyup(function () {
                if($(this).val())
                {
                    $(".loginOrDiv").hide();
                    $("#facebookLoginBtn").hide();
                    $(".loginLineDiv").show();
                    $("#signupNextBtn").show();
                    $("#loginSignupEmailPlaceholder").hide();
                }
                else
                {
                    $(".loginOrDiv").show();
                    $("#facebookLoginBtn").show();
                    $(".loginLineDiv").hide();
                    $("#signupNextBtn").hide();
                    $("#loginSignupEmailPlaceholder").show();
                }
            });

            $("#signupNextBtn").click(function () {
                $("#signupDiv").show();
                $("#signupEmailTextBox").val($("#loginSignupEmailTextBox").val());
                $("#signupNameTextBox").focus();
            });

            $(".signupHeader .backarrow").click(function () {
                $("#signupDiv").hide();
            });

            $("#loginTabHeader").click(function () {
                $("#loginDiv").show();
                $("#loginEmailTextBox").focus();
            });

            $(".loginHeader .backarrow").click(function () {
                $("#loginDiv").hide();
            });

            $("#forgotPasswordBtn").click(function () {
                $("#forgotPasswordDiv").show();
                $("#forgotPasswordEmailTextBox").focus();
            });

            $(".forgotPasswordHeader .backarrow").click(function () {
                $("#forgotPasswordDiv").hide(); 
            });

            $("#signupBtn").click(function () {
                var error = false;
                $("#signupContentDiv input").removeClass("error");
                if (!$("#signupEmailTextBox").val()) {
                    $("#signupEmailTextBox").addClass("error");
                    error = true;
                }
                if (!$("#signupNameTextBox").val()) {
                    $("#signupNameTextBox").addClass("error");
                    error = true;
                }
                if (!$("#signupPasswordTextBox").val()) {
                    $("#signupPasswordTextBox").addClass("error");
                    error = true;
                }
                if (error)
                    return;

                var name = $("#signupNameTextBox").val();
                var firstName = name.indexOf(" ") > 0 ? name.substring(0, name.indexOf(" ")) : name;

                var deviceId = getParameterByName("deviceId");
                var pushDeviceToken = getParameterByName("pushDeviceToken");

                var user = {
                    Name: name, FirstName: firstName, Email: $("#signupEmailTextBox").val(), Password: $("#signupPasswordTextBox").val(),
                    DeviceId: deviceId, PushDeviceToken: pushDeviceToken, Latitude: currentLat, Longitude: currentLng
                };

                Post("SignUpUser", { user: user }, LoginSuccess);
                $("#signupDiv").hide();
                $("#loginSignupDiv").hide();
                MessageBox(firstName + ", Welcome to Pow Wow!");
            });

            $("#loginBtn").click(function () {
                var error = false;
                $("#loginContentDiv input").removeClass("error");
                if (!$("#loginEmailTextBox").val()) {
                    $("#loginEmailTextBox").addClass("error");
                    error = true;
                }
                if (!$("#loginPasswordTextBox").val()) {
                    $("#loginPasswordTextBox").addClass("error");
                    error = true;
                }
                if (error)
                    return;

                var deviceId = getParameterByName("deviceId");
                var pushDeviceToken = getParameterByName("pushDeviceToken");

                var success = function (user) {
                    if(!user)
                        MessageBox("Email or Password is incorrect")
                    else {
                        $("#loginDiv").hide();
                        $("#loginSignupDiv").hide();
                        LoginSuccess(user);
                    }
                }

                Post("LoginUser", { facebookAccessToken: "", deviceId: deviceId, pushDeviceToken: pushDeviceToken, email: $("#loginEmailTextBox").val(), password: $("#loginPasswordTextBox").val() }, success);

            });

            $(".facebookLoginBtn").click(function () {
                if (isiOS) {
                    window.location = "ios:FacebookLogin";
                }
                else if (isAndroid) {
                    if (typeof androidAppProxy !== "undefined")
                        androidAppProxy.AndroidFacebookLogin();
                }
            });

            $("#forgotPasswordSendBtn").click(function () {
                var success = function (result) {
                    $("#forgotPasswordDiv").hide();
                    $("#loginDiv").hide();
                    $("#loginSignupDiv").hide();
                    if (result)
                        MessageBox(result);
                };

                Post("ForgotPassword", { email: $("#forgotPasswordEmailTextBox").val() }, success);
            });

        });

        function OpenLogin() {
            $("#loginSignupDiv").show();
            $("#loginSignupEmailTextBox").focus();
        }

    </script>

    <!-- Menu -->
    <script type="text/javascript">
        $(document).ready(function () {
            $("#menuBtn").click(function () {
                MenuClick();
            });

            $("body").on("click", ".content", function () {
                if ($("#menuDiv").is(':visible'))
                    CloseMenu();
            });

            $("#menuDiv").swipe({
                swipeLeft: function (event, direction, distance, duration, fingerCount) {
                    CloseMenu();
                }
            });

            $("#myGroupsDiv").on("click", "div", function () {
                var groupId = $(this).attr("groupid");
                var success = function (group) {
                    OpenGroupDetails(group);
                    setTimeout(CloseMenu, 500);
                };
                GetGroup(groupId);
            });

            $("#myNotificationsDiv").on("click", "div", function () {
                var eventId = $(this).attr("eventid");
                OpenEventFromNotification(eventId);
            });

        });

        function LoadNotifications() {
            Post("GetNotifications", { userId: currentUser.Id }, PopulateNotifications);
        }

        function PopulateNotifications(results) {
            var html = "";
            for (var i = 0; i < results.length; i++) {
                var notification = results[i];
                var notificationHtml = '<div eventid="{eventId}" style="padding:8px 4px 8px 16px;border-bottom:1px solid #3F4552;"><span style="font-weight:bold;">{Message}</span><div style="padding-top:2px;">{SinceSent}</div></div>';
                notificationHtml = notificationHtml.replace("{eventId}", notification.EventId).replace("{Message}", notification.Message).replace("{SinceSent}", notification.SinceSent);
                html += notificationHtml;
            }

            $("#myNotificationsDiv").html(html);
        }


        function MenuClick() {
            CloseGroups();
            if ($("#menuDiv").is(':visible'))
                CloseMenu();
            else
                OpenMenu();
        }

        function OpenMenu() {
            LoadNotifications();

            $("#menuDiv").show();
            if (isMobile)
            {
                $("#menuDiv").animate({ left: "0" }, 350);
                $(".content").animate({ left: "75%", right: "-75%" }, 350);
            }
            else
                $("#menuDiv").animate({ "margin-left": "300px" }, 350);
        }

        function CloseMenu() {
            if (isMobile) {
                $("#menuDiv").animate({ left: "-75%" }, 350, function () {
                    $("#menuDiv").hide();
                });
                $(".content").animate({ left: "0", right: "0" }, 350 );
            }
            else {
                $("#menuDiv").animate({ "margin-left": "0" }, 350, function () {
                    $("#menuDiv").hide();
                });
            }
        }

        function OpenEventFromNotification(eventId) {
            var success = function (event) {
                OpenEventDetails(event);
                setTimeout(CloseMenu, 500);
            };
            Post("GetEvent", { id: eventId }, success);
        }
    </script>

    <!-- Groups -->
    <script type="text/javascript">
        var groupResults = [];
        var currentGroup = {};

        $(document).ready(function () {
            $("#groupsBtn").click(function () {
                GroupsClick();
            });

            $("#groupAddBtn").click(function () {
                AddEditGroup();
            });

            $("#groupDetailsDiv .detailMenuBtn").click(function () {
                setTimeout(function () { $("#groupEditBtn").show() }, 50);
            });

            $("#groupDetailsDiv").click(function () {
                $("#groupEditBtn").hide();
            });

            $("#groupDetailsDiv .detailMenuBtn").click(function () {
                $("#groupEditBtn").show();
            });

            $("#groupFilterTextBox").keyup(function () {
                var search = $("#groupFilterTextBox").val().toLowerCase();
                if (search.length == 0) {
                    $("#groupsListDiv > div").show();
                    return;
                }
                $("#groupsListDiv > div").each(function () {
                    var name = $(this).find("div").html().toLowerCase();
                    if (name.indexOf(search) >= 0)
                        $(this).show();
                    else
                        $(this).hide();
                });
            });

            $("#groupsListDiv").on("click", "div", function () {
                var groupId = $(this).attr("groupid");
                if (!groupId)
                    return;

                $(groupResults).each(function () {
                    if (this.Id == groupId)
                        GetGroup(groupId);   
                });
            });

            $("#groupDetailsDiv #groupDetailsDescription").on("click", ".readMore", function () {
                $("#groupDetailsDiv #groupDetailsDescription").html(currentGroup.Description);
            });

            $("#groupJoinBtn").click(function () {
                if (!IsGoing(currentGroup.Members, currentUser.Id))
                    JoinGroup();
                else
                    ActionMessageBox("Unjoin " + currentGroup.Name + "?", UnjoinGroup, null, "Yes", "No");
            });

            $("#myGroupsDiv").on("click", ".joinGroupBtn", function () {
                OpenGroups();
                setTimeout(CloseMenu, 500);
            });

            $("#addGroupsResultsDiv").on("click", ".joinGroupBtn", function () {
                $("#addGroupDiv").hide();
                $("#addDiv").hide();
                CloseMessageBox();
                OpenGroups();
            });

            $("#isPublicBtn").click(function () {
                PublicClick();
            });

            $("#groupAddDiv .bottomBtn").click(function () {
                SaveGroup();
            });

            $("#groupEditBtn").click(function () {
                AddEditGroup(currentGroup);
            });

            $("#checkPasswordDiv .smallBottomBtn").click(function () {
                var pwd = $("#checkPasswordDiv input").val();
                if(pwd == currentGroup.Password)
                {
                    $("#checkPasswordDiv").hide();
                    $(".modal-backdrop").hide();
                    currentGroup.HasAccess = true;
                    OpenGroupDetails();
                }
                else
                {
                    $("#checkPasswordDiv").hide();
                    MessageBox("Incorrect Password");
                }
            });

            $("#AddGroupPictureUrl").blur(function () {
                $("#AddGroupPicture").show().attr("src", $(this).val());
            });

        });

        function AddEditGroup(group)
        {
            if (!group)
            {
                currentGroup = {};
                $("#groupAddDiv .screenTitle").html("Create Group");
                $("#groupAddDiv .bottomBtn").html("Create");
                $("#groupAddDiv input").removeClass("error");
                $("#AddGroupDivName").val("");
                $("#AddGroupDescription").val("");
                GetCityName();
                SetPublic(true);
                $("#AddGroupPassword").val("");
                $("#AddGroupPictureUrl").val("");
                $("#AddGroupPicture").hide();
            }
            else
            {
                $("#groupAddDiv .screenTitle").html("Edit Group");
                $("#groupAddDiv .bottomBtn").html("Save");
                $("#groupAddDiv input").removeClass("error");
                $("#AddGroupDivName").val(group.Name);
                $("#AddGroupCity").val(group.City);
                $("#AddGroupDescription").val(group.Description);
                SetPublic(group.IsPublic);
                $("#AddGroupPassword").val(group.Password);
                $("#groupDetailsDiv").hide();
                $("#AddGroupPictureUrl").val(group.PictureUrl);
                $("#AddGroupPicture").show().attr("src", group.PictureUrl);
            }
            $("#groupAddDiv").show();
        }

        function SaveGroup()
        {
            var error = false;
            $("#groupAddDiv input").removeClass("error");
            if (!$("#AddGroupDivName").val())
            {
                $("#AddGroupDivName").addClass("error");
                error = true;
            }
            if (!$("#AddGroupCity").val()) {
                $("#AddGroupCity").addClass("error");
                error = true;
            }
            if (error)
                return;

            currentGroup.Name = $("#AddGroupDivName").val();
            currentGroup.Description = $("#AddGroupDescription").val();
            currentGroup.City = $("#AddGroupCity").val();
            currentGroup.IsPublic = $("#isPublicBtn .selected").html() == "Public";
            currentGroup.Password = $("#AddGroupPassword").val();
            currentGroup.PictureUrl = $("#AddGroupPictureUrl").val();
            currentGroup.UserId = currentGroup.Id ? "" : currentUser.Id;
            if(!currentGroup.IsPublic && !currentGroup.Password)
            {
                MessageBox("Private groups must have passwords to access them.");
                $("#AddGroupPassword").addClass("error");
                return;
            }

            Post("SaveGroup", { group: currentGroup }, OpenGroups);
            $("#groupAddDiv").hide();
            if(!currentGroup.Id)
                MessageBox("Your group " + currentGroup.Name + " has been created.");
        }

        function GetCityName() {
            currentGroup.Latitude = currentLat;
            currentGroup.Longitude = currentLng;

            var latlng = new google.maps.LatLng(currentLat, currentLng);
            var geocoder = new google.maps.Geocoder();
            geocoder.geocode({ 'latLng': latlng }, function (results, status) {
                if (status == google.maps.GeocoderStatus.OK) {
                    if (results[1]) {
                        var indice = 0;
                        for (var j = 0; j < results.length; j++) {
                            if (results[j].types[0] == 'locality') {
                                indice = j;
                                break;
                            }
                        }
                        for (var i = 0; i < results[j].address_components.length; i++) {
                            if (results[j].address_components[i].types[0] == "locality")
                                var city = results[j].address_components[i];
                            if (results[j].address_components[i].types[0] == "administrative_area_level_1")
                                var region = results[j].address_components[i];
                            if (results[j].address_components[i].types[0] == "country")
                                var country = results[j].address_components[i];
                        }
                        $("#AddGroupCity").val(city.long_name + ", " + region.short_name);
                    }
                } 
            });
        }

        function GetGroup(groupId)
        {
            Post("GetGroup", { groupId: groupId, latitude: currentLat, longitude: currentLng, user: currentUser }, OpenGroupDetails);
        }

        function LoadMyGroups() {
            Post("GetGroupsByUser", { userId: currentUser.Id }, PopulateMyGroups);
        }

        function PopulateMyGroups(results) {
            var html = "";
            for (var i = 0; i < results.length; i++) {
                var group = results[i];
                var groupHtml = '<div groupid="{groupId}" style="padding: 12px 4px 12px 16px;border-bottom:1px solid #3F4552;"><span>{Name}</span></div>';
                groupHtml = groupHtml.replace("{groupId}", group.Id).replace("{Name}", group.Name);
                html += groupHtml;
            }
            if (!html)
                html = '<div class="joinGroupBtn" style="padding: 12px 4px 12px 16px;border-bottom:1px solid #3F4552;font-weight: bold;">+ JOIN GROUPS</div>';

            $("#myGroupsDiv").html(html);

            html = "";
            for (var i = 0; i < results.length; i++) {
                var group = results[i];
                console.log(group);
                var groupHtml = '<div groupid="{GroupId}" ><img src="{PictureUrl}" onerror="this.style.display=\'none\';" /><div>{Name}</div></div>';
                groupHtml = groupHtml.replace("{GroupId}", group.Id).replace("{PictureUrl}", group.PictureUrl).replace("{Name}", group.Name);
                html += groupHtml;
            }
            if (!html)
                html = "<div style='text-align: center;'>You are not a member of any groups.</div><div class='blueBtn joinGroupBtn' style='margin: 24px 16%;'>Join Groups</div>";

            $("#addGroupsResultsDiv").html(html);
        }

        function GroupsClick() {
            CloseMenu();
            if ($("#groupsDiv").is(':visible'))
                CloseGroups();
            else
                OpenGroups();
        }

        function LoadGroups() {
            Post("GetGroups", { latitude: currentLat, longitude: currentLng }, PopulateGroups);
        }

        function PopulateGroups(results) {
            groupResults = results;
            var html = "";
            for (var i = 0; i < results.length; i++) {
                var group = results[i];
                var groupHtml = '<div groupid="{GroupId}" >{Img}<div>{Name}</div></div>';
                var img = group.PictureUrl ? '<img src="' + group.PictureUrl + '" />' : '<img src="../Img/group.png" class="logo" />';
                groupHtml = groupHtml.replace("{GroupId}", group.Id).replace("{Img}", img).replace("{Name}", group.Name);
                html += groupHtml;
            }

            $("#groupsListDiv").html(html);
        }

        function OpenGroups() {
            LoadGroups();
            $("#groupFilterTextBox").val("");
            $("#groupsDiv").show();
        }

        function CloseGroups() {
            $("#groupsDiv").hide();
        }

        function OpenGroupDetails(group) {
            if (group)
                currentGroup = group;

            if (!currentGroup.IsPublic && !IsGoing(currentGroup.Members, currentUser.Id) && !currentGroup.HasAccess) {
                $("#checkPasswordDiv input").val("");
                $("#checkPasswordDiv").show();
                $(".modal-backdrop").show();
                return;
            }

            $("#groupDetailsDiv").show();
            $("#groupDetailsDiv .screenTitle").html(currentGroup.Name);
            $("#groupDetailsLogo").show().attr("src", currentGroup.PictureUrl);
            var subheaderHtml = "<span style='font-weight:bold;'>" + currentGroup.Members.length + "</span> Members - " + currentGroup.City;
            $("#groupDetailsDiv #groupDetailsInfo").html(subheaderHtml);

            var descHtml = currentGroup.Description;
            if (descHtml.length > 110) {
                descHtml = descHtml.substring(0, 110) + " ... ";
                descHtml += "<a class='readMore'>Read More</a>";
            }

            $("#groupDetailsDiv #groupDetailsDescription").html(descHtml);
            $("#groupDetailsDiv #groupEvents").html(SetLocalTimes(group.EventsHtml));

            if (IsGoing(currentGroup.Members, currentUser.Id)) {
                $("#groupJoinBtn").html("MEMBER");
                $("#groupJoinBtn").addClass("selected");
            }
            else {
                $("#groupJoinBtn").html("+ JOIN GROUP");
                $("#groupJoinBtn").removeClass("selected");
            }

            if (IsAdmin(currentGroup.Members, currentUser.Id))
                $("#groupDetailsDiv .detailMenuBtn").show();
            else
                $("#groupDetailsDiv .detailMenuBtn").hide();
        }

        function JoinGroup() {
            if (!currentUser || !currentUser.Id) {
                OpenLogin();
                return;
            }

            $("#groupJoinBtn").html("MEMBER");
            $("#groupJoinBtn").addClass("selected");

            currentGroup.UserId = currentUser.Id;
            var user = { GroupId: currentGroup.Id, UserId: currentUser.Id, FacebookId: currentUser.FacebookId, FirstName: currentUser.FirstName, IsAdmin: false };
            currentGroup.Members.push(user);
            var subheaderHtml = "<span style='font-weight:bold;'>" + currentGroup.Members.length + "</span> Members - " + currentGroup.City;
            $("#groupDetailsDiv #groupDetailsInfo").html(subheaderHtml);

            Post("JoinGroup", { group: currentGroup }, LoadMyGroups);
        }

        function UnjoinGroup() {
            $("#groupJoinBtn").html("+ JOIN GROUP");
            $("#groupJoinBtn").removeClass("selected");

            currentGroup.UserId = currentUser.Id;
            RemoveByUserId(currentGroup.Members, currentUser.Id);
            var subheaderHtml = "<span style='font-weight:bold;'>" + currentGroup.Members.length + "</span> Members - " + currentGroup.City;
            $("#groupDetailsDiv #groupDetailsInfo").html(subheaderHtml);

            Post("UnjoinGroup", { group: currentGroup }, LoadMyGroups);
        }

        function SetPublic(isPublic) {
            var marginLeft = isPublic ? "0px" : "44%";
            $(".pillBtn .slider").css({ "margin-left": marginLeft });
            $(".pillBtn div").removeClass("selected");
            var idx = isPublic ? 1 : 2;
            $(".pillBtn div:eq(" + idx + ")").addClass("selected");
        }

        function PublicClick() {
            var isPublic = $("#isPublicBtn .selected").html() == "Public";

            var marginLeft = isPublic ? "44%" : "0px";
            $(".pillBtn .slider").animate({ "margin-left": marginLeft }, 350, function () {
                var idx = isPublic ? 2 : 1;
                $(".pillBtn div").removeClass("selected");
                $(".pillBtn div:eq(" + idx + ")").addClass("selected");
                $("#AddGroupPassword").attr("readonly", !isPublic);
                $("#AddGroupPassword").val("");
            });
        }
    </script>

    <!-- Location -->
    <script type="text/javascript">
        var locationResults = [];
        var currentLocation = {};

        $(document).ready(function () {
            $("#AddLocation").focus(function () {
                $("#locationSearchTextbox").val("");
                $("#locationResults").html("");
                $("#locationDiv").show();
                $("#locationSearchTextbox").focus();
            });

            $("#locationSearchTextbox").keyup(function () {
                var search = $("#locationSearchTextbox").val();
                if (search.length < 3) {
                    $("#locationResults").html("");
                    return;
                }

                Post("GetLocations", { searchName: search, latitude: currentLat, longitude: currentLng }, PopulateLocations);
            });

            $("#locationResults").on("click", "div", function () {
                var idx = $(this).attr("locationIdx");
                AddLocation(idx);
            });

        });

        function PopulateLocations(locations) {
            locationResults = locations;
            var html = "";
            if (locationResults.length == 1 && !locationResults[0].Name) {
                html = '<div locationIdx="-1" style="border:none;" ><span style="font-weight:bold;color:#4285F4;">Just use "' + $("#locationSearchTextbox").val() + '"</span></div>';
            }
            else {
                for (var i = 0; i < locationResults.length; i++) {
                    var location = locationResults[i];
                    var locationHtml = '<div locationIdx="' + i + '" ><span style="font-weight:bold;">{Name}</span><div></div>{Address}</div>';
                    html += locationHtml.replace("{Name}", location.Name).replace("{Address}", location.Address);
                }
            }
            $("#locationResults").html(html);
        }

        function AddLocation(index) {
            if (index == -1) {
                var address = $("#locationSearchTextbox").val() + ", " + locationResults[0].Address;
                var geocoder = new google.maps.Geocoder();
                geocoder.geocode({ 'address': address }, function (results, status) {
                    if (status == google.maps.GeocoderStatus.OK) {
                        currentLocation = { Name: $("#locationSearchTextbox").val(), Address: $("#locationSearchTextbox").val(), Latitude: results[0].geometry.location.lat(), Longitude: results[0].geometry.location.lng() };
                        PlotMap("AddMap", currentLocation.Name, currentLocation.Latitude, currentLocation.Longitude);
                        $("#AddLocation").val(currentLocation.Name);
                    }
                });
            }
            else {
                currentLocation = locationResults[index];
                PlotMap("AddMap", currentLocation.Name, currentLocation.Latitude, currentLocation.Longitude);
                $("#AddLocation").val(currentLocation.Name);
            }

            $("#locationDiv").hide();
            locationResults = [];
        }

        function PlotMap(mapName, name, lat, lng) {
            $("#" + mapName).show();

            var latLng = new google.maps.LatLng(lat, lng);
            var mapOptions = {
                zoom: 15,
                center: latLng,
                mapTypeId: google.maps.MapTypeId.ROADMAP
            }

            var map = new google.maps.Map(document.getElementById(mapName), mapOptions);
            var marker = new google.maps.Marker({
                position: latLng,
                map: map,
                title: name
            });
        }

    </script>

    <!-- Messages -->
    <script type="text/javascript">
        $(document).ready(function () {
            $(".messageBtn").click(function () {
                OpenMessages();
            });

            $("#sendText").focus(function () {
                setTimeout(function () { $("#messageDiv").scrollTop($("#messageDiv").height()); }, 200)
            });

            $("#sendText").keypress(function (e) {
                if (e.which == 13) {
                    SendMessage();
                }
            });

            $("#messageDiv .backArrow").click(function () {
                CloseMessages();
            });
        });

        function OpenMessages() {
            $("#addBtn").hide();
            $("#DetailMap").hide();
            $("#messageDiv").show();
            $("#messageDiv").show();
            $("#messageDiv .screenTitle").html(currentEvent.Name);
            $(".messageBtn").attr("src", "/Img/message.png");
            LoadMessages();
        }

        function LoadMessages() {
            Post("GetMessages", { eventId: currentEvent.Id }, PopulateMessages);
        }

        function PopulateMessages(messages) {
            var html = "";
            for (var i = 0; i < messages.length; i++) {
                var message = messages[i];
                if (Contains(message.Id, currentUser.Id)) {
                    var messageHtml = "<div style='float:right;clear:both;margin-top: 8px;'>{SinceSent}</div><div class='meMessage'>{Message}</div>";
                    html += messageHtml.replace("{SinceSent}", message.SinceSent).replace("{Message}", message.Message);
                }
                else {
                    var messageHtml = "<div style='float:left;clear:both;margin-top: 8px;'>{From} - {SinceSent}</div><div class='youMessage'>{Message}</div>";
                    html += messageHtml.replace("{From}", message.Name).replace("{SinceSent}", message.SinceSent).replace("{Message}", message.Message);
                }
            }
            $("#MessageResults").html(html);
            $("#MessageResults").scrollTop($("#MessageResults").height());
        }

        function SendMessage() {
            var text = $("#messageDiv input").val();
            if(!text)
                return;
            
            var message = { EventId: currentEvent.Id, Name: currentUser.FirstName, Message: text, UserId: currentUser.Id };
            Post("SendMessage", { message: message }, LoadMessages);
            $("#messageDiv input").val("");
        }

        function CloseMessages() {
            $("#addBtn").show();
            $("#DetailMap").show();
            $("#messageDiv").hide();
        }

    </script>

    <!-- Clock -->
    <script type="text/javascript">
            $(document).ready(function () {
                $("#AddStartTime").click(function () {
                    InitClock();
                });

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

                var date = new Date;
                var hr = date.getHours();
                var AMPM = hr > 11 ? "PM" : "AM";

                $(".ampm").removeClass("selected");
                $(".ampm").each(function () {
                    if ($(this).html() == AMPM)
                        $(this).addClass("selected");
                });

                $("#clockDiv .time").html("--:-- " + AMPM);

                var wd = $("#clockCircle").width();
                $("#clockCircle").height(wd * .8);

                var radius = (wd / 2) * .7;
                var html = "";
                var centerX = wd / 2;
                var centerY = wd / 2 + 60;
                for (var i = 1; i < 13; i++) {
                    var x = Math.cos(2 * Math.PI * ((i - 3) / 12)) * radius + centerX;
                    var y = Math.sin(2 * Math.PI * ((i - 3) / 12)) * radius + centerY;
                    html += '<div class="hour" style="position:absolute;left:' + x + 'px;top:' + y + 'px;">' + i + '</div>';
                }
                $("#clockCircle").append(html);


                //if (!$("#clockDiv .time").html().length) {
                //    var date = new Date;
                //    var min = date.getMinutes();
                //    if (min < 10)
                //        min = "0" + min;
                //    var hr = date.getHours();
                //    var AMPM = "AM";
                //    if (hr > 11)
                //        AMPM = "PM";
                //    if (hr > 12)
                //        hr -= 12;
                //    if (hr == 0)
                //        hr = 12;

                //    $(".ampm").each(function () {
                //        if ($(this).html() == AMPM)
                //            $(this).addClass("selected");
                //    });

                //    $("#clockDiv .time").html(hr + ":" + min + " " + AMPM);
                //}
                //else {
                //    var time = $("#clockDiv .time").html();
                //    var hr = time.substring(0, time.indexOf(":"));
                //}

                //var wd = $("#clockCircle").width();
                //$("#clockCircle").height(wd * .8);

                //var radius = (wd / 2) * .7;
                //var html = "";
                //var centerX = wd / 2;
                //var centerY = wd / 2 + 60;
                //for (var i = 1; i < 13; i++) {
                //    var x = Math.cos(2 * Math.PI * ((i - 3) / 12)) * radius + centerX;
                //    var y = Math.sin(2 * Math.PI * ((i - 3) / 12)) * radius + centerY;
                //    if (i == hr) {
                //        html += '<div class="selected hour" style="position:absolute;left:' + x + 'px;top:' + y + 'px;">' + i + '</div>';
                //    }
                //    else {
                //        html += '<div class="hour" style="position:absolute;left:' + x + 'px;top:' + y + 'px;">' + i + '</div>';
                //    }

                //}
                //$("#clockCircle").append(html);
            }

            function HourClicked(hr) {

                var time = $("#clockDiv .time").html();
                time = time.substring(time.indexOf(":"));
                var min = +time.substring(1, time.indexOf(" "));
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

    <!-- Facebook -->
    <%--<script type="text/javascript">
        var currentUser;
        var fbAccessToken;

        window.fbAsyncInit = function () {
            
            FB.init({
                appId: '397533583786525', // App ID
                status: true, // check login status
                cookie: true, // enable cookies to allow the server to access the session
                xfbml: true  // parse XFBML
            });

            fbAccessToken = getParameterByName("fbAccessToken");
            var deviceId = getParameterByName("deviceId");
            var pushDeviceToken = getParameterByName("pushDeviceToken");
            if (fbAccessToken) {
                Post("LoginUser", { facebookAccessToken: fbAccessToken, deviceId: deviceId, pushDeviceToken: pushDeviceToken }, LoginSuccess);
            }
            else
            {
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

                        Post("LoginUser", { facebookAccessToken: fbAccessToken, deviceId: deviceId, pushDeviceToken: pushDeviceToken }, LoginSuccess);

                    } else {
                        Post("LoginUser", { facebookAccessToken: fbAccessToken, deviceId: deviceId, pushDeviceToken: pushDeviceToken }, LoginSuccess);
                        //if (!fbAccessToken)
                        //    window.location = "../";
                        //else
                        //    Post("LoginUser", { facebookAccessToken: fbAccessToken }, LoginSuccess);
                    }
                });
            }
        };

        function LoginSuccess(results) {
            currentUser = results;
            $("#FacebookId").val(currentUser.FacebookId);
            //LoadEvents();
            /*TODO: fix
            if (document.URL.indexOf("?") > 0) {
                var referenceId = document.URL.substr(document.URL.indexOf("?") + 1);
                Post("GetReferredNotification", { referenceId: referenceId, facebookId: currentUser.FacebookId }, OpenReferredNotification);
            }
            */
        }

        function OpenFacebookLogin()
        {
            OpenFromBottom("facebookLoginDiv");
        }

        function FacebookLogin() {
            if (isiOS) {
                window.location = "ios:FacebookLogin";
            }
            else if(isAndroid)
            {
                if (typeof androidAppProxy !== "undefined")
                    androidAppProxy.AndroidFacebookLogin();
            }
            else
            {
                FB.login(function (response) {
                    if (response.authResponse) {
                        var uid = response.authResponse.userID;
                        $("#FacebookId").val(uid);
                        fbAccessToken = response.authResponse.accessToken;
                        var deviceId = getParameterByName("deviceId");
                        var pushDeviceToken = getParameterByName("pushDeviceToken");

                        Post("LoginUser", { facebookAccessToken: fbAccessToken, deviceId: deviceId, pushDeviceToken: pushDeviceToken }, LoginSuccess);
                        CloseToBottom('facebookLoginDiv');
                    } else {
                        console.log('User cancelled login or did not fully authorize.');
                    }
                });
            }
        }

        function FacebookLogout() {
            FB.logout(function (response) {
                // user is now logged out
            });
        }

        // Load the SDK Asynchronously
        (function (d) {
            var js, id = 'facebook-jssdk', ref = d.getElementsByTagName('script')[0];
            if (d.getElementById(id)) { return; }
            js = d.createElement('script'); js.id = id; js.async = true;
            js.src = "//connect.facebook.net/en_US/all.js";
            ref.parentNode.insertBefore(js, ref);
        }(document));
    </script>--%>

    <!-- Branch -->
    <script type="text/javascript">

        (function (b, r, a, n, c, h, _, s, d, k) { if (!b[n] || !b[n]._q) { for (; s < _.length;) c(h, _[s++]); d = r.createElement(a); d.async = 1; d.src = "https://cdn.branch.io/branch-v1.6.7.min.js"; k = r.getElementsByTagName(a)[0]; k.parentNode.insertBefore(d, k); b[n] = h } })(window, document, "script", "branch", function (b, r) { b[r] = function () { b._q.push([r, arguments]) } }, { _q: [], _v: 1 }, "init data first addListener removeListener setIdentity logout track link sendSMS referrals credits creditHistory applyCode validateCode getCode redeem banner closeBanner".split(" "), 0);

        branch.init('key_live_hmpTgy1sVLhPXtjDUW5hVoldyDfpel4T', function (err, data) {
            // callback to handle err or data
        });

        function GetBranchLink(event, phoneList, message)
        {
            branch.link({
                channel: isiOS ? "iOS" : isAndroid ? "Android" : "Web",
                feature: 'share',
                stage: 'Event Invite',
                data: {
                    ReferenceName: currentUser.Name,
                    ReferenceId: event.ReferenceId
                }
            }, function (err, link) {
                message = message.replace("{Branch}", link);
                SendText(phoneList, message);
                //console.log(err, link);
            });
        }

        //function SendBranchSMS()
        //{
        //    branch.sendSMS(
        //        '7135015344',
        //        {
        //            tags: ['tag1', 'tag2'],
        //            channel: 'facebook',
        //            feature: 'dashboard',
        //            stage: 'new user',
        //            data: {
        //                mydata: 'something',
        //                foo: 'bar',
        //                '$desktop_url': 'http://myappwebsite.com',
        //                '$ios_url': 'http://myappwebsite.com/ios',
        //                '$ipad_url': 'http://myappwebsite.com/ipad',
        //                '$android_url': 'http://myappwebsite.com/android',
        //                '$og_app_id': '12345',
        //                '$og_title': 'My App',
        //                '$og_description': 'My app\'s description.',
        //                '$og_image_url': 'http://myappwebsite.com/image.png'
        //            }
        //        },
        //        { make_new_link: true }, // Default: false. If set to true, sendSMS will generate a new link even if one already exists.
        //        function (err) { console.log(err); }
        //    );
        //}

</script>

</head>
<body>
    <form id="form1" runat="server">
        <div id="fb-root"></div>
        <input type="hidden" id="FacebookId" runat="server" />
        <div class="modal-backdrop"></div>
        <div class="loading"><img src="../Img/loading.gif" /></div>
        <div class="header">
            <div>
                <img id="menuBtn" src="/Img/whiteMenu.png" />
                <img class="title" src="/Img/title.png" />
                <img id="groupsBtn" src="/Img/whiteSearch.png" />
            </div>
        </div>
        <div class="content">
            <div style="min-height:500px;"></div>
        </div>
        <img id="addBtn" src="../Img/add.png" />
        <div id="menuDiv">
            <div class="menuHeader" style="border-top: none;padding-top:10px;">MY GROUPS</div>
            <div id="myGroupsDiv"></div>
            <div class="menuHeader" >NOTIFICATIONS</div>
            <div id="myNotificationsDiv"></div>
        </div>
        <div id="groupsDiv">
            <div class="groupsHeader"><img class="groupsSearch" src="../Img/graySearch.png" /><input id="groupFilterTextBox" type="text" placeholder="Search Groups" />
                <img id="groupAddBtn" src="../Img/grayAdd.png" />
            </div>
            <div id="groupsListDiv"></div>
        </div>
        <div id="groupAddDiv" class="screen">
            <div class="screenHeader">
                <div class="backArrow" ></div>
                <div class="screenTitle">Create Group</div>
            </div>
            <div class="screenContent">
                <input id="AddGroupDivName" type="text" placeholder="Your Group Name" style="margin:12px 0 4px;" />
                <input id="AddGroupCity" type="text" placeholder="City" style="margin-bottom:4px;" />
                <textarea id="AddGroupDescription" rows="4" placeholder="Description"></textarea>
                <div id="isPublicBtn" class="pillBtn" style="margin:10px 0 12px;clear:both;">
                    <div class="slider"></div>
                    <div style="margin: -26px 0 0 18%;float:left;" class="selected">Public</div>
                    <div style="margin: -26px 18% 0 0;float:right;">Private</div>
                </div>
                <input id="AddGroupPassword" type="text" placeholder="Private Password" style="margin-bottom:4px;" readonly="readonly" />
                <input id="AddGroupPictureUrl" type="text" placeholder="Logo Image Url"  />
                <img id="AddGroupPicture" style="height: 80px;margin: 8px 0;" onerror="this.style.display='none';" />
            </div>
            <div class="screenBottom"><div class="bottomBtn">Create</div></div>
        </div>
        <div id="groupDetailsDiv" class="screen">
            <div class="screenHeader">
                <div class="backArrow" ></div>
                <div class="screenTitle"></div>
                <img class="detailMenuBtn" src="/Img/smallmenu.png" />
                <div id="groupEditBtn">Edit</div>
            </div>
            <div class="screenSubheader">
                <img id="groupDetailsLogo" onerror="this.style.display='none';" />
                <div id="groupDetailsInfo"></div>
                <div id="groupJoinBtn" class="joinBtn">+ JOIN GROUP</div>
            </div>
            <div class="screenContent">
                <div id="groupDetailsDescription"></div>
                <div id="groupEvents"></div>
            </div>
            <img id="addFromGroupBtn" src="../Img/add.png">
        </div>
        <div id="addDiv" class="screen">
            <div class="screenHeader">
                <div class="backArrow" ></div>
                <div class="screenTitle">Create Event</div>
            </div>
            <div class="screenContent">
                <input id="AddName" type="text" placeholder="What do you want to do?" style="margin:12px 0 4px;" />
                <input id="AddLocation" type="text" placeholder="Location" style="width:48%;float:left;margin-bottom:4px;" />
                <input id="AddStartTime" type="text" placeholder="Start Time" readonly="readonly" style="width:32%;float:right;" />
                <textarea id="AddDetails" rows="4" placeholder="Details"></textarea>
                <input id="AddGroupName" type="text" placeholder="Add to Group" style="margin: 8px 0 2px;" />
                <div style="float:left;margin:16px 0;">Total People?</div>
                <input id="AddMax" type="number" placeholder="Max" style="width:15%;float:right;margin-left:4px;" />
                <input id="AddMin" type="number" placeholder="Min" style="width:15%;float:right;" />
                <div id="AddMap" style="clear:both;"></div>
                <div id="deleteEventBtn" style="text-align:center;color:#4285F4;margin: 16px 0 8px;display:none;">Close Event</div>
            </div>
            <div class="screenBottom"><div class="bottomBtn">Create</div></div>
        </div>
        <div id="detailsDiv" class="screen">
            <div class="screenHeader">
                <div class="backArrow" ></div>
                <div class="screenTitle"></div>
                <img class="detailMenuBtn" src="/Img/smallmenu.png" />
                <img class="messageBtn" src="/Img/message.png" />
                <div id="detailsEditBtn">Edit</div>
            </div>
            <div class="screenSubheader">
                <img id="detailsLogo" onerror="this.style.display='none';" />
                <div id="detailsInfo"></div>
                <div id="joinBtn" class="joinBtn">+ JOIN EVENT</div>
            </div>
            <div class="screenContent">
                <div id="detailsDescription"></div>
                <div id="detailsHowMany" style="text-align:center;"></div>
                <div id="detailsInvitedFriends" class="invitedFriends" ><div class="invitedFriendsScroll"></div></div>
                <div id="detailsMap"></div>
            </div>
        </div>
        <div id="messageDiv" class="screen">
            <div class="screenHeader">
                <div class="backArrow" ></div>
                <div class="screenTitle"></div>
            </div>
            <div id="MessageResults"></div>
            <div id="sendDiv">
                <input id="sendText" type="text" placeholder="Message" />
                <div onclick="SendMessage();">Send</div>
            </div>
        </div>
        <div id="locationDiv" class="screen">
            <div class="screenHeader">
                <div class="backArrow" ></div>
                <div class="screenTitle">Add Location</div>
            </div>
            <div class="screenContent">
                <input id="locationSearchTextbox" type="text" placeholder="Search" style="margin:12px 0;" />
                <div id="locationResults"></div>
            </div>
        </div>
        <div id="loginSignupDiv">
            <div class="loginSignupHeader">
                <img class="backarrow" src="/Img/whitebackarrow.png" />
                <img class="title" src="/Img/title.png" />
                <div class="subtitle">Sign up to discover activities<br /> near you today.</div>
                <div id="signupTabHeader" class="loginTabHeaders selected">SIGN UP<div class="arrowUp"></div></div>
                <div id="loginTabHeader" class="loginTabHeaders" style="left: 50%;">LOG IN<div class="arrowUp"></div></div>
            </div>
            <div id="signupTab">
                <input id="loginSignupEmailTextBox" /><div id="loginSignupEmailPlaceholder" >Enter your email</div>
                <div class="loginOrDiv" style="float:left;border-top:1px solid #B5B5B5;margin:8px 0 0 5%;width: 38%;"></div><div class="loginOrDiv" style="float:left;width:13.8%;text-align: center;color:#B5B5B5">OR</div><div class="loginOrDiv" style="float:right;border-top:1px solid #B5B5B5;margin:8px 5% 0 0;width: 38%;"></div>
                <div id="facebookLoginBtn" class="facebookLoginBtn" style="clear: both;text-align: center;color:#4285F4;"><img src="../Img/fbIcon.png" style="height: 20px;margin: 8px 10px 0 0;vertical-align: bottom;" />Sign up with Facebook</div>
                <div class="loginLineDiv" style="float:left;border-top:1px solid #B5B5B5;margin:8px 0 0 5%;width: 90%;margin-bottom: 12px;display:none;"></div>
                <div id="signupNextBtn" style="text-align: center;color:#4285F4;font-size:20px;display:none;">Next</div>
            </div>
        </div>
        <div id="signupDiv">
            <div class="signupHeader">
                <img class="backarrow" src="/Img/whitebackarrow.png" />
                <img class="title" src="/Img/title.png" />
            </div>
            <div id="signupContentDiv">
                <img src="../Img/grayenvelope.png" /><input id="signupEmailTextBox" placeholder="Your email" />
                <img src="../Img/grayface.png" style="margin-top: 2px;" /><input id="signupNameTextBox" placeholder="Your name" />
                <img src="../Img/graylock.png" style="margin-top: 0;" /><input id="signupPasswordTextBox" type="password" placeholder="Password" />
                <div id="signupBtn">Sign Up</div>
            </div>
        </div>
        <div id="loginDiv">
            <div class="loginHeader">
                <img class="backarrow" src="/Img/whitebackarrow.png" />
                <img class="title" src="/Img/title.png" />
            </div>
            <div id="loginContentDiv">
                <img src="../Img/grayenvelope.png" /><input id="loginEmailTextBox" placeholder="Your email" />
                <img src="../Img/graylock.png" /><input id="loginPasswordTextBox" type="password" placeholder="Password" />
                <div id="forgotPasswordBtn">Forgot?</div>
                <div id="loginBtn" style="margin-bottom:12px;">Log In</div>
                <div style="float:left;border-top:1px solid #B5B5B5;margin:8px 0 0 5%;width: 38%;"></div><div style="float:left;width:13.8%;text-align: center;color:#B5B5B5">OR</div><div style="float:right;border-top:1px solid #B5B5B5;margin:8px 5% 0 0;width: 38%;"></div>
                <div class="facebookLoginBtn" style="clear: both;text-align: center;color:#4285F4;"><img src="../Img/fbIcon.png" style="height: 20px;margin: 8px 10px 0 0;vertical-align: bottom;float: none;" />Log in with Facebook</div>

            </div>
        </div>
        <div id="forgotPasswordDiv">
            <div class="forgotPasswordHeader">
                <img class="backarrow" src="/Img/whitebackarrow.png" />
                <img class="title" src="/Img/title.png" />
            </div>
            <div id="forgotPasswordContentDiv">
                <img src="../Img/grayenvelope.png" /><input id="forgotPasswordEmailTextBox" placeholder="Your email" />
                <div id="forgotPasswordSendBtn" style="margin-bottom:12px;">Send Password</div>
            </div>
        </div>
        <div id="clockDiv">
            <div class="time"></div>
            <div id="clockCircle"></div>
            <div class="ampm" style="float:left;">AM</div>
            <div class="ampm" style="float:right;">PM</div>
            <div onclick='$("#clockDiv").fadeOut();$(".modal-backdrop").fadeOut();' class="smallBottomBtn" >Cancel</div>
        </div>
        <div id="addGroupDiv">
            <div id="addGroupsResultsDiv"></div>
            <div class="smallBottomBtn" >Cancel</div>
        </div>
        <div id="checkPasswordDiv">
            <div class="messageContent" style="margin-bottom: 12px;line-height: 1.4em;">This group is private. Enter group password.</div>
            <input type="text" placeholder="Group Password" style="margin-bottom:50px;" />
            <div class="smallBottomBtn">Ok</div>
        </div>
        <div id="MessageBox">
            <div class="messageContent"></div>
            <div onclick="CloseMessageBox();" class="smallBottomBtn">Ok</div>
        </div>
        <div id="ActionMessageBox">
            <div class="messageContent"></div>
            <div class="yesBtn smallBottomBtn" style="left:0;right:50%;"">Ok</div><div onclick="CloseMessageBox();" class="noBtn smallBottomBtn" style="left:50%;right:0;border-left:1px solid #ccc;">Cancel</div>
        </div>
    </form>
</body>
</html>
