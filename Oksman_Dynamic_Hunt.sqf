/*
How to USE:
Script is dynamic, it should launch as soon as first trigger or mission starts depending on your preference. When the enemy faction knows of the players on the ground, all enemy forces in specified radius will start hunting the players. They will not follow if players are extracted via helicopters or hunt helilcopters on their own. Ground vehicles will be hunted.

Code to Launch:
null = [ENEMYFACTION,MINRANGE,MAXANGE] execVM "Oksman_Dynamic_Hunt.sqf";

Example:
null = [WEST,1000,2000] execVM "Oksman_Dynamic_Hunt.sqf";
*/


if (hasInterface && !isServer) exitWith {false};	// Ensures only server or HC runs this script - Tack Neky

OKS_EnemyFaction = _this select 0;
OKS_MinRange = _this select 1;
OKS_MaxRange = _this select 2;


oks_hunted = false;
oks_activated=true;
oks_debug=true;

publicVariable "OKS_EnemyFaction";
publicVariable "OKS_MinRange";
publicVariable "OKS_MaxRange";
publicVariable "oks_hunted";
publicVariable "oks_activated";
publicVariable "oks_debug";


if (oks_debug) then {SystemChat "hunt.sqf started"; "hunt.sqf started" remoteExecCall ["SystemChat"];};


/*
* Loop and find out if AllPlayers are KnownTo Enemy Faction. Once known is true, then fill the knownPlayers into Array.
* Then for each Enemy Group look for allPlayers if Inside Array & Within Range. If so then Hunt, if not then cancel until next KnownTo Loop?
*/


OKS_Hunt =
{

		params ["_Player","_PlayerArray"];

		/*
		*  This code is run for all known players. Take the player, find the nearest enemies of the players.
		*  When you have the list of all Enemies, run the OKS_Hunting for all enemies near the player.
		*/
		_list = _Player nearEntities [["Man", "Car", "Motorcycle", "Tank"], OKS_MinRange];
		_listAir = _Player nearEntities ["Air", OKS_MinRange + OKS_MinRange];

		_nearenemies = _list select {side _X == OKS_EnemyFaction && isFormationLeader _X;};
		{
			_X setVariable ["isHunting", false];
			if !(_X getVariable ["isHunting",false]) then
			{
				_X setVariable ["isHunting", true];
				[_X,_PlayerArray] spawn OKS_Hunting;
			}

		} foreach _nearenemies;

		_nearAir = _listAir select {side _X == OKS_EnemyFaction && isFormationLeader _X;};
		{
			_X setVariable ["isHunting", false];
			if !(_X getVariable ["isHunting",false]) then
			{
				_X setVariable ["isHunting", true];
				[_X,_PlayerArray] spawn OKS_Hunting;
			}

		} foreach _nearAir;

};

OKS_Hunting =
{

	params ["_Hunter","_PlayerArray"];


		/*
		The Hunter Group is known and the PlayerArray is sent into code. Use the Hunter and the PlayerArray to sort the array
		Find the nearest target in PlayerArray and hunt that.
		*/

		_sorted = [_PlayerArray,[],{_x distance _Hunter},"ASCEND"] call BIS_fnc_sortBy;
		_nearestPlayer = _sorted select 0;

	    if(oks_debug) then {hint format ["Array: %1\n\nTarget: %2",_sorted,_nearestPlayer]; "Array & Target" remoteExecCall ["SystemChat"];};


	    /*
	    If Hunter has more than 1 waypoint. Delete, doStop and Reset.
	    */
		/// For future use: getVariable ["ACE_isUnconscious", false];



		{ if(_X getVariable ["ACE_isUnconscious", false]) then{_X setDamage 1;}  } foreach units group _Hunter;


		if(_Hunter distance _NearestPlayer < OKS_MaxRange && !(_Hunter getVariable ["GW_Common_disableAI_Path", false]))
		then
		{

			if(count waypoints group _Hunter>0)
			then
			{
					{deleteWaypoint((waypoints group _Hunter)select 0)}forEach waypoints group _Hunter;

					if !(Vehicle _Hunter isKindOf "LandVehicle") then
					{
						{doStop _X; _X doFollow leader group _X} foreach units group _Hunter;
					};
			};

				sleep 5;

				if(oks_debug) then {SystemChat format ["Nearest Player: %1  Hunter: %2",_nearestPlayer,_Hunter];  "Nearest Player" remoteExecCall ["SystemChat"];};

					_wp = group _Hunter addWaypoint [position _nearestPlayer, 0];
					_wp setWaypointType "MOVE";
					_wp setWaypointSpeed "NORMAL";

					if (vehicle _Hunter isKindOf "LandVehicle") then { _wp setWaypointBehaviour"SAFE"; }
					else { _wp setWaypointBehaviour "AWARE"; };






						sleep 1;

						if (vehicle _hunter isKindOf "LandVehicle") then
						{
							_null = [group _Hunter, position _nearestPlayer, 600] call bis_fnc_taskPatrol;
						};
						if (vehicle _hunter isKindOf "Air") then
						{
							_null = [group _Hunter, position _nearestPlayer, 1000] call bis_fnc_taskPatrol;
						};
						if (vehicle _hunter isKindOf "Man") then
						{
							_null = [group _Hunter, position _nearestPlayer, 300] call bis_fnc_taskPatrol;
						};

						{ _X setWaypointSpeed "FULL"; } foreach waypoints _Hunter;

		};
};



while {oks_activated} do
{
	if (oks_debug) then {systemChat "oks_activated True"; "oks_activated TRUE" remoteExecCall ["SystemChat"]; };
	_playerHunted = [];


		{
			if ((OKS_EnemyFaction knowsAbout _X > 0.5 || OKS_EnemyFaction knowsAbout vehicle _X > 0.5 ) && isTouchingGround (vehicle _X))
			then
			{_playerHunted pushBackUnique _X; oks_hunted = true; if(oks_debug) then {systemChat format ["OKS_Hunted true. KnowsAbout: %1",OKS_EnemyFaction knowsAbout _X]; }; sleep 0.5;}

		} foreach (AllPlayers - (Entities "HeadlessClient_F"));

	if (oks_debug) then {SystemChat Format ["AllPlayers Done. List: %1",_playerHunted]; "AllPlayers Done" remoteExecCall ["SystemChat"]; };

	/*
	*If a target is above 0.5 & isTouchinGround then Hunted is true. Initiate the OKS_Hunt for all Players in _PlayerHunted AKA all players known to enemy faction.
	*/
	if (oks_hunted) then
	{

		if (oks_debug) then {systemChat "Initiated Hunted"; "Initiated Hunted" remoteExecCall ["SystemChat"]; };

		{
			if (alive _X && !(_x getVariable ["ACE_isUnconscious", false])) then { [_X,_playerHunted] spawn OKS_Hunt; }
		} foreach _playerHunted;



	};

	sleep 60;

};