<script>
    import {onMount} from 'svelte';
    import {fade} from 'svelte/transition';
    import NPUtils from './utils.js';

    let devices = [];
    let policyAtsign = {};
    let deviceAtsigns = [];
    let firstDeviceAtsign = {};
    let eventStream;
    let showForm = false;
    let submitResponse = '';
    let commandToExecute = '';

    onMount(async () => {
        let targetUri = 'n/a';
        try {
            targetUri = '/api/admin/devices';
            devices = await NPUtils.loadData(targetUri);
        } catch (error) {
            alert('Error loading from ' + targetUri + ' : ' + error.message);
        }

        try {
            targetUri = '/api/admin/info';
            let info = await NPUtils.loadData(targetUri);
            console.log(info);
            policyAtsign = info.policyAtsign;
            deviceAtsigns = info.deviceAtsigns;
            firstDeviceAtsign = deviceAtsigns[0];
        } catch (error) {
            alert('Error loading from ' + targetUri + ' : ' + error.message);
        }

        try {
            targetUri = '/api/admin/ws';
            eventStream = new WebSocket(targetUri);

            eventStream.onopen = function () {
            };

            eventStream.onmessage = function (event) {
                console.log(event);
                let eventData = JSON.parse(event.data);
                if (eventData.type === 'DeviceInfo') {
                    let found = false;
                    for (let i = 0; i < devices.length; i++) {
                        if (devices[i].devicename === eventData.payload.devicename) {
                            found = true;
                            devices[i] = eventData.payload;
                        }
                    }
                    if (!found) {
                        devices.push(eventData.payload);
                    }
                    devices = devices;
                }
            };

            eventStream.onclose = function (event) {
            };

            eventStream.onerror = function (error) {
                alert('Error on websocket to ' + targetUri + ' : ' + JSON.stringify(error));
            };

            return () => eventStream.close();
        } catch (error) {
            alert('Error creating websocket to ' + targetUri + ' : ' + error.message);
        }
    });

    async function onNewDeviceSubmit(e) {
        const formData = new FormData(e.target);

        const data = {};
        for (let field of formData) {
            const [key, value] = field;
            data[key] = value;
        }

        submitResponse = '';
        try {
            let res = await NPUtils.saveData('POST', '/api/admin/devices', data);
            commandToExecute=res.command;
        } catch (error) {
            submitResponse = error.message;
        }
    }

    function bgForDevice(device) {
        if (device.status === 'Active') {
            return 'mediumseagreen';
        } else {
            return 'lightsalmon';
        }
    }

</script>

<div class="row">
    <div class="col">
        {#key devices}
            <div class="row border border-primary rounded-3" style="background-color: lightblue" in:fade={{ duration: 600 }}>
                <div class="col">
                    <h3>Devices</h3>
                    <table class="table">
                        <thead>
                        <tr>
                            <th>Device Name</th>
                            <th>Status</th>
                            <th>Timestamp</th>
                            <th>Device AtSign</th>
                            <th>Policy AtSign</th>
                            <th>Device Group Name</th>
                        </tr>
                        </thead>
                        <tbody>
                        {#each devices as device, i}
                            <tr>
                                <td style="background-color: {bgForDevice(device)}">
                                    {device.devicename}
                                </td>
                                <td style="background-color: {bgForDevice(device)}">
                                    {device.status}
                                </td>
                                <td style="background-color: {bgForDevice(device)}">
                                    {new Date(device.timestamp).toLocaleString('en-GB', {timeZoneName: 'short'})}
                                </td>
                                <td style="background-color: {bgForDevice(device)}">
                                    {device.deviceAtsign}
                                </td>
                                <td style="background-color: {bgForDevice(device)}">
                                    {device.policyAtsign}
                                </td>
                                <td style="background-color: {bgForDevice(device)}">
                                    {device.deviceGroupName}
                                </td>
                            </tr>
                        {/each}
                        </tbody>
                        <!-- TODO add a form for adding a new device -->
                    </table>
                </div>
            </div>
        {/key}

        <hr/>

        <div class="row">
            <div class="col">
                <button type="button" class="btn btn-outline-success"
                        on:click={() => {
                            commandToExecute = '';
                            submitResponse = '';
                            showForm = true;
                        }}
                >Add new device
                </button>

                {#if showForm}
                    <form on:submit|preventDefault={onNewDeviceSubmit}>
                        <div>
                            <label for="devicename">Device Name</label>
                            <input
                                    type="text"
                                    id="devicename"
                                    name="devicename"
                                    value=""
                            />
                        </div>
                        <div>
                            <label for="deviceAtsign">Device Atsign</label>
                            <input
                                    type="text"
                                    id="deviceAtsign"
                                    name="deviceAtsign"
                                    value="{firstDeviceAtsign.atSign}"
                            />
                        </div>
                        <div>
                            <label for="policyAtsign">Managing Atsign</label>
                            <input
                                    type="text"
                                    id="policyAtsign"
                                    name="policyAtsign"
                                    value="{policyAtsign.atSign}"
                            />
                        </div>
                        <button type="submit" class="btn btm-sm btn-outline-primary">Submit</button>
                        <button type="button" class="btn btn-sm btn-outline-warning"
                                on:click={() => {
                            commandToExecute = '';
                            submitResponse = '';
                            showForm = false;
                        }}
                        >Cancel
                        </button>
                    </form>
                    <div style="color: red">{submitResponse}</div>
                    <div>{commandToExecute}</div>
                {/if}
            </div>
        </div>
    </div>
</div>
