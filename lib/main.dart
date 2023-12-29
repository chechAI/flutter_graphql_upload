import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import "package:http/http.dart" show MultipartFile;
import "package:http_parser/http_parser.dart" show MediaType;
import 'package:image_picker/image_picker.dart';

const createAssets = r'''
      mutation CreateAssets($input: [CreateAssetInput!]!) {
          createAssets(input: $input) {
              ... on Asset {
                  id
                  createdAt
                  updatedAt
                  name
                  fileSize
                  mimeType
                  type
                  preview
                  source
                  width
                  height
                  focalPoint {
                      x
                      y
                  }
                  tags {
                      id
                      value

                  }
              }
              ... on ErrorResult {
                  message
              }
          }
      }
  ''';

const uploadImage = r"""
    mutation($file: Upload!) {
      upload(file: $file)
    }
""";

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final httpLink = HttpLink(
      dotenv.env['ADMIN_API']!,
    );

    final client = ValueNotifier<GraphQLClient>(
      GraphQLClient(
        cache: GraphQLCache(),
        link: httpLink,
      ),
    );

    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: GraphQLProvider(
        client: client,
        child: const Scaffold(
          body: MyHomePage(title: 'Graphql image upload'),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _image;
  bool _uploadInProgress = false;

  _uploadImage(BuildContext context) async {
    setState(() {
      _uploadInProgress = true;
    });

    var byteData = _image!.readAsBytesSync();

    var multipartFile = MultipartFile.fromBytes(
      'photo',
      byteData,
      filename: '${DateTime.now().second}.jpg',
      contentType: MediaType("image", "jpg"),
    );

    var files = [multipartFile];
    final input = files.map((file) => {"file": file, "tags": 'zzz'}).toList();
    print('input: $input');

    var opts = MutationOptions(
        fetchPolicy: FetchPolicy.noCache,
        document: gql(createAssets),
        variables: {
          "input": input,
        });

    var client = GraphQLProvider.of(context).value;
    var results = await client.mutate(opts);

    setState(() {
      _uploadInProgress = false;
    });

    var message = results.hasException
        ? results.exception!.graphqlErrors.join(", ")
        : "Image was uploaded successfully!";
    print(message);
    // final snackBar = SnackBar(content: Text(message));
    // Scaffold.of(context).showSnackBar(snackBar);
  }

  final ImagePicker _picker = ImagePicker();

  Future selectImage() async {
    var image = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _image = File(image!.path);
      print('image: $_image');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_image != null)
              Flexible(
                flex: 9,
                child: Image.file(_image!),
              )
            else
              const Flexible(
                flex: 9,
                child: Center(
                  child: Text("No Image Selected"),
                ),
              ),
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  ElevatedButton(
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.photo_library),
                        SizedBox(
                          width: 5,
                        ),
                        Text("Select File"),
                      ],
                    ),
                    onPressed: () => selectImage(),
                  ),
                  // Mutation Widget Here
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _isLoadingInProgress() {
    return _uploadInProgress
        ? const CircularProgressIndicator()
        : const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.file_upload),
              SizedBox(
                width: 5,
              ),
              Text("Upload File"),
            ],
          );
  }
}