<script>
    import NPUtils from './utils.js';
    import {onMount} from 'svelte';
    import {fade} from 'svelte/transition';
    import InPlaceEdit from './InPlaceEdit.svelte'

    let groups = [];

    let selectedGroupIndex = -1;

    let status = '';
    let statusColor = 'green';
    let statusTimeout;

    let eventStream;
    let events = [];

    function selectGroup(ix, event) {
        console.log('group selected: ', groups[ix], 'event', event);
        selectedGroupIndex = ix;
    }

    function bgForGroup(ix) {
        if (ix === selectedGroupIndex) {
            return 'cadetblue';
        } else {
            return 'lightblue';
        }
    }

    function bgForEvent(eventData) {
        if (eventData.type === 'DeviceInfo') {
            return 'lightblue';
        } else if (eventData.type === 'PolicyCheck') {
            if (eventData.payload.authorized) {
                return 'mediumseagreen';
            } else {
                return 'palevioletred'
            }
        } else {
            return 'lightblue';
        }
    }

    function detailsForEvent(eventData) {
        if (eventData.type === 'DeviceInfo') {
            return 'Heartbeat';
        } else if (eventData.type === 'PolicyCheck') {
            return 'User: ' + eventData.payload.userAtsign
                + ';  PermitOpen: ' + eventData.payload.permitOpen;
        } else {
            return JSON.stringify(eventData);
        }
    }

    function submit(object, field) {
        return ({detail: newValue}) => {
            // IRL: POST value to server here
            console.log(`updated ${object}, new value for ${field} is: "${newValue}"`)
            // object[field] = newValue;
            // object = object;
            // users = users;
            // groups = groups;
        }
    }

    function displayStatus(msg, isError, t) {
        if (!t) {
            t = 1500;
        }
        statusColor = 'green';
        if (isError) {
            t = 5000;
            statusColor = 'red';
        }
        console.error(msg);
        if (statusTimeout) {
            clearTimeout(statusTimeout);
        }
        status = msg;
        if (msg !== '') {
            statusTimeout = setTimeout(() => {
                status = ''
            }, t)
        }
    }

    async function updateGroup(group) {
        displayStatus('Saving group data ... ');
        try {
            await NPUtils.saveData('PUT', '/api/policy/group/' + group.id, group);
            displayStatus('Saving group data ... saved');
        } catch (error) {
            displayStatus(error.message, true);
        }
    }

    async function createGroup(group) {
        displayStatus('Creating new group ... ');
        try {
            group = await NPUtils.saveData('POST', '/api/policy/group', group);
            displayStatus('Creating new group ... done');
            groups.push(group);
            groups = groups;
        } catch (error) {
            displayStatus(error.message, true);
        }
    }

    async function deleteGroup(group) {
        try {
            displayStatus('Deleting group ...');
            await NPUtils.deleteData('/api/policy/group/' + group.id);
            displayStatus('Deleting group ... done');
            groups.splice(groups.indexOf(group), 1);
            groups = groups;
        } catch (error) {
            displayStatus(error.message, true);
        }
    }

    onMount(async () => {
        displayStatus('Loading ...')
        let targetUri = 'n/a';
        try {
            targetUri = '/api/policy/group';
            groups = await NPUtils.loadData(targetUri);
            if (status === 'Loading ...') {
                displayStatus('Data loaded');
            }
        } catch (error) {
            alert('Error loading from ' + targetUri + ' : ' + error.message);
        }

        try {
            targetUri = '/api/policy/events';
            events = await NPUtils.loadData(targetUri);
            if (status === 'Loading ...') {
                displayStatus('Data loaded');
            }
        } catch (error) {
            alert('Error loading from ' + targetUri + ' : ' + error.message);
        }

        try {
            targetUri = '/api/policy/ws';
            eventStream = new WebSocket(targetUri);

            eventStream.onopen = function() {
            };

            eventStream.onmessage = function(event) {
                console.log(event);
                events.unshift(JSON.parse(event.data));
                events = events;
            };

            eventStream.onclose = function (event) {
            };

            eventStream.onerror = function (error) {
                alert('Error on websocket to ' + targetUri + ' : ' + JSON.stringify(error));
            };

            return () => eventStream.close();
        } catch (error) {
            displayStatus(error.message, true);
        }
    });

</script>

<div class="row" style="color: {statusColor}; text-align: center">
    {#if status !== ''}
        <h2>{status}</h2>
    {:else}
        <h2>&nbsp;</h2>

    {/if}
</div>

<div class="row">
    <div class="col-4">
        <div class="row">
            {#key selectedGroupIndex}
                <div class="border border-primary rounded-3" style="background-color: lightblue">
                    <h2>Permission Groups</h2>
                    <table class="table">
                        <thead>
                        <tr>
                            <th></th>
                            <th>Name</th>
                            <th>Description</th>
                        </tr>
                        </thead>
                        <tbody>
                        {#each groups as group, i}
                            <tr on:click={(e) => selectGroup(i, e)}>
                                <td style="background-color: {bgForGroup(i)}">
                                    <button type="button" class="btn btn-sm btn-outline-danger"
                                            on:click={() => {
                                            deleteGroup(group);
                                        }}
                                    >Delete
                                    </button>
                                </td>
                                <td style="background-color: {bgForGroup(i)}">
                                    <InPlaceEdit
                                            bind:value={group.name}
                                            on:submit={() => updateGroup(group)}
                                    />
                                </td>
                                <td style="background-color: {bgForGroup(i)}">
                                    <InPlaceEdit
                                            bind:value={group.description}
                                            on:submit={() => updateGroup(group)}
                                    />
                                </td>
                            </tr>
                        {/each}
                        <tr>
                            <td>
                                <button type="button" class="btn btn-sm btn-outline-success"
                                        on:click={async () => {
                                        let newGroup = {
                                            name:'New group name',
                                            description:'New group description',
                                            userAtSigns: [],
                                            daemonAtSigns: [],
                                            devices: [],
                                            deviceGroups: [],
                                        };
                                        await createGroup(newGroup);
                                    }}
                                >Add new
                                </button>
                            </td>
                            <td></td>
                            <td></td>
                        </tr>
                        </tbody>
                    </table>
                </div>
            {/key}
        </div>
    </div>
    <div class="col-8">
        {#key selectedGroupIndex}
            <div class="row" in:fade={{ duration: 600 }}>
                {#if selectedGroupIndex >= 0 && selectedGroupIndex < groups.length}
                    <div class="border border-primary rounded-3" style="background-color:cadetblue">
                        <h3>Permission Group: {groups[selectedGroupIndex].name}</h3>
                        <table class="table">
                            <thead>
                            </thead>
                            <tbody>
                            <tr>
                                <td>
                                    <InPlaceEdit
                                            bind:value={groups[selectedGroupIndex].description}
                                            on:submit={() => updateGroup(groups[selectedGroupIndex])}
                                    />
                                </td>
                            </tr>
                            </tbody>
                        </table>
                        <div class="row">
                            <div class="col">
                                <h4>Devices</h4>
                                <table class="table">
                                    <thead>
                                    <tr>
                                        <th></th>
                                        <th>Name</th>
                                        <th>Access</th>
                                    </tr>
                                    </thead>
                                    <!--suppress JSUnresolvedVariable -->
                                    <tbody>
                                    {#each groups[selectedGroupIndex].devices as device}
                                        <tr>
                                            <td>
                                                <button type="button" class="btn btn-sm btn-outline-danger" style="font-size:10px"
                                                        on:click={() => {
                                                        let g = groups[selectedGroupIndex];
                                                        g.devices.splice(g.devices.indexOf(device), 1);
                                                        // trigger svelte to update the DOM
                                                        groups = groups;
                                                        updateGroup(g);
                                                    }}
                                                >Delete
                                                </button>
                                            </td>
                                            <td>
                                                <InPlaceEdit
                                                        bind:value={device.name}
                                                        on:submit={() => updateGroup(groups[selectedGroupIndex])}
                                                />
                                            </td>
                                            <td>
                                                <table>
                                                    <thead style="display:none"></thead>
                                                    <!--suppress JSUnresolvedVariable -->
                                                    <tbody>
                                                    {#each device.permitOpens as po, i}
                                                        <tr>
                                                            <td>
                                                                <button type="button" class="btn btn-sm btn-outline-danger" style="font-size:10px"
                                                                        on:click={() => {
                                                                    device.permitOpens.splice(device.permitOpens.indexOf(po), 1);
                                                                    // trigger svelte to update the DOM
                                                                    groups = groups;
                                                                    updateGroup(groups[selectedGroupIndex]);
                                                                }}
                                                                >-
                                                                </button>
                                                            </td>
                                                            <td>
                                                                <InPlaceEdit
                                                                        bind:value={po}
                                                                        on:submit={() => updateGroup(groups[selectedGroupIndex])}
                                                                />
                                                            </td>
                                                        </tr>
                                                    {/each}
                                                    <tr>
                                                        <td>
                                                            <button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px"
                                                                    on:click={() => {
                                                                    device.permitOpens.push('host:port');
                                                                    // trigger svelte to update the DOM
                                                                    groups = groups;
                                                                    updateGroup(groups[selectedGroupIndex]);
                                                                }}
                                                            >+
                                                            </button>
                                                        </td>
                                                    </tr>
                                                    </tbody>
                                                </table>
                                            </td>
                                        </tr>
                                    {/each}
                                    <tr>
                                        <td>
                                            <button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px"
                                                    on:click={() => {
                                                    let g = groups[selectedGroupIndex];
                                                    g.devices.push({name:'device name', permitOpens: []});
                                                    // trigger svelte to update the DOM
                                                    groups = groups;
                                                    updateGroup(groups[selectedGroupIndex]);
                                                }}
                                            >+
                                            </button>
                                        </td>
                                        <td></td>
                                        <td></td>
                                    </tr>
                                    </tbody>
                                </table>
                            </div>
                            <div class="col">
                                <h4>Daemons</h4>
                                <table class="table">
                                    <thead>
                                    <tr>
                                        <th></th>
                                        <th>atSign</th>
                                    </tr>
                                    </thead>
                                    <!--suppress JSUnresolvedVariable -->
                                    <tbody>
                                    {#each groups[selectedGroupIndex].daemonAtSigns as daemonAtSign}
                                        <tr>
                                            <td>
                                                <button type="button" class="btn btn-sm btn-outline-danger" style="font-size:10px"
                                                        on:click={() => {
                                                        let g = groups[selectedGroupIndex];
                                                        g.daemonAtSigns.splice(g.daemonAtSigns.indexOf(daemonAtSign), 1);
                                                        g.daemonAtSigns = g.daemonAtSigns;
                                                        // trigger svelte to update the DOM
                                                        groups = groups;
                                                        updateGroup(g);
                                                    }}
                                                >Delete
                                                </button>
                                            </td>
                                            <td>
                                                <InPlaceEdit
                                                        bind:value={daemonAtSign}
                                                        on:submit={() => updateGroup(groups[selectedGroupIndex])}
                                                />
                                            </td>
                                        </tr>
                                    {/each}
                                    <tr>
                                        <td>
                                            <button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px"
                                                    on:click={() => {
                                                    let g = groups[selectedGroupIndex];
                                                    g.daemonAtSigns.push('@some_atsign');
                                                    // trigger svelte to update the DOM
                                                    groups = groups;
                                                    updateGroup(g);
                                                }}
                                            >Add
                                            </button>
                                        </td>
                                        <td></td>
                                    </tr>
                                    </tbody>
                                </table>
                            </div>
<!--                            <div class="col">-->
<!--                                <h4>Device Groups</h4>-->
<!--                                <table class="table">-->
<!--                                    <thead>-->
<!--                                    <tr>-->
<!--                                        <th></th>-->
<!--                                        <th>Name</th>-->
<!--                                        <th>Access</th>-->
<!--                                    </tr>-->
<!--                                    </thead>-->
<!--                                    &lt;!&ndash;suppress JSUnresolvedVariable &ndash;&gt;-->
<!--                                    <tbody>-->
<!--                                    {#each groups[selectedGroupIndex].deviceGroups as dg}-->
<!--                                        <tr>-->
<!--                                            <td>-->
<!--                                                <button type="button" class="btn btn-sm btn-outline-danger" style="font-size:10px"-->
<!--                                                        on:click={() => {-->
<!--                                                        let g = groups[selectedGroupIndex];-->
<!--                                                        g.deviceGroups.splice(g.deviceGroups.indexOf(dg), 1);-->
<!--                                                        // trigger svelte to update the DOM-->
<!--                                                        groups = groups;-->
<!--                                                        updateGroup(groups[selectedGroupIndex]);-->
<!--                                                    }}-->
<!--                                                >Delete-->
<!--                                                </button>-->
<!--                                            </td>-->
<!--                                            <td>-->
<!--                                                <InPlaceEdit-->
<!--                                                        bind:value={dg.name}-->
<!--                                                        on:submit={() => updateGroup(groups[selectedGroupIndex])}-->
<!--                                                />-->
<!--                                            </td>-->
<!--                                            <td>-->
<!--                                                <table>-->
<!--                                                    <thead style="display:none; border-width: 0"></thead>-->
<!--                                                    &lt;!&ndash;suppress JSUnresolvedVariable &ndash;&gt;-->
<!--                                                    <tbody>-->
<!--                                                    {#each dg.permitOpens as po, i}-->
<!--                                                        <tr>-->
<!--                                                            <td>-->
<!--                                                                <button type="button" class="btn btn-sm btn-outline-danger" style="font-size:10px"-->
<!--                                                                        on:click={() => {-->
<!--                                                                    dg.permitOpens.splice(dg.permitOpens.indexOf(po), 1);-->
<!--                                                                    // trigger svelte to update the DOM-->
<!--                                                                    groups = groups;-->
<!--                                                                    updateGroup(groups[selectedGroupIndex]);-->
<!--                                                                }}-->
<!--                                                                >- -->
<!--                                                                </button>-->
<!--                                                            </td>-->
<!--                                                            <td>-->
<!--                                                                <InPlaceEdit-->
<!--                                                                        bind:value={po}-->
<!--                                                                        on:submit={() => updateGroup(groups[selectedGroupIndex])}-->
<!--                                                                />-->
<!--                                                            </td>-->
<!--                                                        </tr>-->
<!--                                                    {/each}-->
<!--                                                    </tbody>-->
<!--                                                    <tr>-->
<!--                                                        <td>-->
<!--                                                            <button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px"-->
<!--                                                                    on:click={() => {-->
<!--                                                                    dg.permitOpens.push('host:port');-->
<!--                                                                    // trigger svelte to update the DOM-->
<!--                                                                    groups = groups;-->
<!--                                                                    updateGroup(groups[selectedGroupIndex]);-->
<!--                                                                }}-->
<!--                                                            >+-->
<!--                                                            </button>-->
<!--                                                        </td>-->
<!--                                                    </tr>-->
<!--                                                </table>-->
<!--                                            </td>-->
<!--                                        </tr>-->
<!--                                    {/each}-->
<!--                                    <tr>-->
<!--                                        <td>-->
<!--                                            <button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px"-->
<!--                                                    on:click={() => {-->
<!--                                                    let g = groups[selectedGroupIndex];-->
<!--                                                    g.deviceGroups.push({name:'device group name', permitOpens: []});-->
<!--                                                    // trigger svelte to update the DOM-->
<!--                                                    groups = groups;-->
<!--                                                    updateGroup(groups[selectedGroupIndex]);-->
<!--                                                }}-->
<!--                                            >+-->
<!--                                            </button>-->
<!--                                        </td>-->
<!--                                        <td></td>-->
<!--                                        <td></td>-->
<!--                                    </tr>-->
<!--                                    </tbody>-->
<!--                                </table>-->
<!--                            </div>-->
                            <div class="col">
                                <h4>Members</h4>
                                <table class="table">
                                    <thead>
                                    <tr>
                                        <th></th>
                                        <th>atSign</th>
                                    </tr>
                                    </thead>
                                    <!--suppress JSUnresolvedVariable -->
                                    <tbody>
                                    {#each groups[selectedGroupIndex].userAtSigns as userAtSign}
                                        <tr>
                                            <td>
                                                <button type="button" class="btn btn-sm btn-outline-danger" style="font-size:10px"
                                                        on:click={() => {
                                                        let g = groups[selectedGroupIndex];
                                                        let index = g.userAtSigns.indexOf(userAtSign);
                                                        g.userAtSigns.splice( index, 1);
                                                        // trigger svelte to update the DOM
                                                        groups = groups;
                                                        updateGroup(g);
                                                        }
                                                    }
                                                >Delete
                                                </button>
                                            </td>
                                            <td>
                                                <InPlaceEdit
                                                        bind:value={userAtSign}
                                                        on:submit={() => updateGroup(groups[selectedGroupIndex])}
                                                />
                                            </td>
                                        </tr>
                                    {/each}
                                    <tr>
                                        <td>
                                            <button type="button" class="btn btn-sm btn-outline-success" style="font-size:10px"
                                                    on:click={() => {
                                                    let g = groups[selectedGroupIndex];
                                                    g.userAtSigns.push('@some_atsign');
                                                    // trigger svelte to update the DOM
                                                    groups = groups;
                                                    updateGroup(g);
                                                    }
                                                }
                                            >Add
                                            </button>
                                        </td>
                                        <td></td>
                                    </tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                {/if}
            </div>
        {/key}
    </div>
</div>

<hr/>

<!-- Logs -->
<div class="row">
    <div class="border border-primary rounded-3" style="background-color: lightblue">
        <h2>Logs</h2>

        {#key events}
            <table class="table">
                <thead>
                    <tr>
                        <th style="width: 16%">Timestamp</th>
                        <th style="width: 11%">Type</th>
                        <th style="width: 11%">DeviceAtSign</th>
                        <th style="width: 6%">Device</th>
                        <th style="width: 6%">DeviceGroup</th>
                        <th style="width: 50%">Details</th>
                    </tr>
                </thead>
                <tbody in:fade={{ duration: 3000 }}>
                {#each events as eventData}
                    <tr>
                        <td style="background-color: {bgForEvent(eventData)}">
                            {new Date(eventData.payload.timestamp).toLocaleString('en-GB', {timeZoneName: 'short'})}
                        </td>
                        <td style="background-color: {bgForEvent(eventData)}">
                            {eventData.type}
                        </td>
                        <td style="background-color: {bgForEvent(eventData)}">
                            {eventData.payload.deviceAtsign}
                        </td>
                        <td style="background-color: {bgForEvent(eventData)}">
                            {eventData.payload.devicename}
                        </td>
                        <td style="background-color: {bgForEvent(eventData)}">
                            {eventData.payload.deviceGroupName}
                        </td>
                        <td style="background-color: {bgForEvent(eventData)}">
                            {detailsForEvent(eventData)}
                        </td>
                    </tr>
                {/each}
                </tbody>
            </table>
        {/key}
    </div>
</div>
