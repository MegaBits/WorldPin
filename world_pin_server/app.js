var io = require('socket.io')(3000);

io.sockets.on('connection', function (socket) {
    socket.broadcast.emit('join', socket['id']);
    console.log(socket['id'] + ' has connected!');
    socket.on('location', function (data) {
		console.log('Location data' + socket['id'] +' has this data ' + data);
	    socket.broadcast.emit('update', (socket['id'] + ':' + data));
	});
	socket.on('disconnect', function () {
	   	socket.broadcast.emit('disappear', socket['id']);
	    console.log(socket['id'] + ' has disconnected!');
	});
});