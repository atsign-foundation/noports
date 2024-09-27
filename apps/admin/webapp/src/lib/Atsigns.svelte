<script>
    import {onMount} from 'svelte';
    import NPUtils from './utils.js';

    let policyAtsign = {};
    let deviceAtsigns = [];
    let eventStream;

    onMount(async () => {
        let targetUri = 'n/a';
        try {
            targetUri = '/api/admin/info';
            let info = await NPUtils.loadData(targetUri);
            policyAtsign = info.policyAtsign;
            deviceAtsigns = info.deviceAtsigns;
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
                if (eventData.type === 'AtsignEvent') {

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

</script>

<div class="row">
    <div class="col-6">
        <div class="border border-primary rounded-3" style="background-color: lightblue">
            <h4>Client Atsign: </h4>
            <ul><li>{policyAtsign.atSign} ({policyAtsign.status})</li></ul>
            <hr/>
            <h4>Device Atsign(s)</h4>
            <ul>
                {#each deviceAtsigns as das}
                    <li>
                        {das.atSign} ({das.status})
                    </li>
                {/each}
            </ul>
        </div>
    </div>
</div>
