import http from 'k6/http';
import { check, sleep } from 'k6';

export default function() {
    var url = `${__ENV.VOTE_URL}`
    var r = http.get(url);

    check(r, {
        'status is 200': r => r.status === 200,
    });

    var choices = [ 'Dogs', 'Cats' ];
    var choice = choices[Math.floor(Math.random()*choices.length)];
    var payload = `vote=${choice}`;
    var params = {
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        }
    }

    r = http.post(url, payload, params)

    check(r, {
        'status is 200': r => r.status === 200,
    });

    // sleep(1);
}
